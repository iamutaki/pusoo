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

import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pusoo/features/track/domain/models/track.dart';
import 'package:pusoo/features/track/domain/usecases/refresh_all_track_usecase.dart';
import 'package:pusoo/features/track/presentation/providers/track_providers.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';
import 'package:pusoo/shared/errors/failure.dart';
import 'package:pusoo/shared/utils/m3u.dart';
import 'package:pusoo/shared/utils/usecase.dart';

/// Re-fetches the active source's M3U from its remote URL, replaces its tracks
/// in the local DB, then refreshes the home UI — throttled to at most once per
/// day via the source's existing `lastUpdated` column.
///
/// Triggered fire-and-forget on app start (see main.dart). It is silent on
/// failure: a network/parse error keeps the existing tracks and leaves
/// `lastUpdated` untouched so the next launch retries.
class AutoRefreshActiveSourceUsecase implements UseCase<void, NoParams> {
  final RefreshAllTrackUsecase _refreshUi;

  AutoRefreshActiveSourceUsecase(this._refreshUi);

  /// Minimum gap between two auto-refreshes of the same source.
  static const minInterval = Duration(hours: 24);

  @override
  Future<Either<Failure, void>> call(NoParams? params) async {
    final source = await (driftDb.select(driftDb.sourceDrift)
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();

    final url = source?.url?.trim();
    if (source == null || url == null || url.isEmpty) {
      return Right(null);
    }

    // ponytail: throttle via the source's existing lastUpdated column — no new
    // storage. A failed refresh leaves lastUpdated untouched so it retries later.
    final now = DateTime.now();
    if (source.lastUpdated != null &&
        now.difference(source.lastUpdated!) < minInterval) {
      return Right(null);
    }

    final sourceId = source.id;
    final tracks = await _fetchTracks(url);
    if (tracks == null || tracks.isEmpty) return Right(null);

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

    // surface the fresh data in the home UI
    await _refreshUi.call(NoParams());
    debugPrint(
      'auto-refresh: source $sourceId refreshed with ${tracks.length} tracks',
    );
    return Right(null);
  }

  /// Fetches + parses the remote M3U, returning null (silent) on any failure.
  Future<List<Track>?> _fetchTracks(String url) async {
    try {
      return await fetchAndParseM3u(url);
    } catch (e) {
      debugPrint('auto-refresh: fetch failed, keeping existing tracks: $e');
      return null;
    }
  }
}

// ponytail: plain Provider (no build_runner) for a one-off bootstrap usecase.
final autoRefreshActiveSourceUsecaseProvider =
    Provider<AutoRefreshActiveSourceUsecase>((ref) {
  return AutoRefreshActiveSourceUsecase(
    ref.read(refreshAllTrackUsecaseProvider),
  );
});
