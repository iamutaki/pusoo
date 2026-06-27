/*
 * Pusoo - IPTV Player
 * Copyright (C) 2025 Ibnul Mutaki <ibnuul@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pusoo/features/track/domain/models/track.dart';
import 'package:pusoo/features/track/presentation/providers/track_providers.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';
import 'package:pusoo/shared/utils/m3u.dart';
import 'package:pusoo/shared/utils/usecase.dart';

/// Re-syncs the active source's M3U from its remote URL, replaces its tracks in
/// the local DB, then refreshes the home UI.
///
/// Used two ways:
/// - **Auto** (app start, no `force`): throttled to once/24h via the source's
///   `lastUpdated` column. Silent on failure — existing tracks are kept and the
///   next launch retries.
/// - **Manual** (`force: true`): bypasses the throttle.
///
/// Returns the number of tracks synced, or null when nothing happened (no
/// active source / no url / throttled / fetch failed).
class AutoRefreshActiveSourceUsecase {
  final Ref _ref;

  AutoRefreshActiveSourceUsecase(this._ref);

  /// Minimum gap between two auto-refreshes of the same source.
  static const minInterval = Duration(hours: 24);

  Future<int?> call({bool force = false}) async {
    final source = await (driftDb.select(driftDb.sourceDrift)
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();

    final url = source?.url?.trim();
    if (source == null || url == null || url.isEmpty) return null;

    // ponytail: throttle via the source's existing lastUpdated column — no new
    // storage. A failed refresh leaves lastUpdated untouched so it retries later.
    final now = DateTime.now();
    if (!force &&
        source.lastUpdated != null &&
        now.difference(source.lastUpdated!) < minInterval) {
      return null;
    }

    final sourceId = source.id;
    final tracks = await _fetchTracks(url);
    if (tracks == null || tracks.isEmpty) return null;

    await driftDb.transaction(() async {
      await (driftDb.delete(driftDb.trackDrift)
            ..where((t) => t.sourceId.equals(sourceId)))
          .go();
      await driftDb.batch(
        (b) => b.insertAll(driftDb.trackDrift, trackCompanions(sourceId, tracks)),
      );
      await (driftDb.update(driftDb.sourceDrift)
            ..where((t) => t.id.equals(sourceId)))
          .write(SourceDriftCompanion(lastUpdated: drift.Value(now)));
    });

    // read fresh: refreshAllTrackUsecaseProvider is autoDispose, so capturing its
    // instance would hold a Ref that later gets disposed → UnmountedRefException.
    await _ref.read(refreshAllTrackUsecaseProvider).call(NoParams());
    debugPrint(
      '${force ? 'manual' : 'auto'}-refresh: source $sourceId synced '
      '${tracks.length} tracks',
    );
    return tracks.length;
  }

  /// Fetches + parses the remote M3U, returning null (silent) on any failure.
  Future<List<Track>?> _fetchTracks(String url) async {
    try {
      return await fetchAndParseM3u(url);
    } catch (e) {
      debugPrint('refresh: fetch failed, keeping existing tracks: $e');
      return null;
    }
  }
}

// ponytail: plain Provider (no build_runner) for a bootstrap usecase.
final autoRefreshActiveSourceUsecaseProvider =
    Provider<AutoRefreshActiveSourceUsecase>((ref) {
  return AutoRefreshActiveSourceUsecase(ref);
});
