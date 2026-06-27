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
 * along with this program. If not, see <https://www.gnu.org/licenses>.
 */

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pusoo/features/source/presentation/providers/active_source_notifier.dart';
import 'package:pusoo/features/track/presentation/providers/track_providers.dart';
import 'package:pusoo/shared/config/inject_default_playlist.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';
import 'package:pusoo/shared/utils/m3u.dart';
import 'package:pusoo/shared/utils/usecase.dart';
import 'package:ulid/ulid.dart';

enum InjectDefaultPlaylistStatus { idle, injecting }

/// UI-facing status so HomeScreen can show a loading overlay during the
/// first-run injection. Stays [InjectDefaultPlaylistStatus.idle] on the skip
/// path (playlist already exists) and whenever the feature is disabled.
class InjectDefaultPlaylistStatusNotifier
    extends Notifier<InjectDefaultPlaylistStatus> {
  @override
  InjectDefaultPlaylistStatus build() => InjectDefaultPlaylistStatus.idle;

  void set(InjectDefaultPlaylistStatus value) => state = value;
}

final injectDefaultPlaylistStatusProvider = NotifierProvider<
    InjectDefaultPlaylistStatusNotifier, InjectDefaultPlaylistStatus>(
  InjectDefaultPlaylistStatusNotifier.new,
);

/// Seeds a default playlist (see [injectDefaultPlaylistName]) on first launch.
///
/// Flow: if a source with that name already exists → skip. Otherwise fetch the
/// M3U, then insert source + tracks in a single transaction (so a failed fetch
/// leaves nothing behind and retries next launch). The seeded source becomes
/// active only when there is no other source yet.
class InjectDefaultPlaylistUsecase {
  final Ref _ref;

  InjectDefaultPlaylistUsecase(this._ref);

  Future<void> call() async {
    if (!injectDefaultPlaylistEnabled) return;

    // already seeded → skip the whole flow
    final existing = await (driftDb.select(driftDb.sourceDrift)
          ..where((t) => t.name.equals(injectDefaultPlaylistName))
          ..limit(1))
        .get();
    if (existing.isNotEmpty) return;

    _ref
        .read(injectDefaultPlaylistStatusProvider.notifier)
        .set(InjectDefaultPlaylistStatus.injecting);
    try {
      // fetch first so a network/parse failure commits nothing
      final tracks = await fetchAndParseM3u(injectDefaultPlaylistUrl);
      if (tracks.isEmpty) return;

      final now = DateTime.now();
      final countExpression = driftDb.sourceDrift.id.count();
      final count =
          await (driftDb.selectOnly(driftDb.sourceDrift)
                ..addColumns([countExpression]))
              .map((row) => row.read(countExpression))
              .getSingle();

      await driftDb.transaction(() async {
        final sourceId = await driftDb.into(driftDb.sourceDrift).insert(
              SourceDriftCompanion.insert(
                ulid: Ulid().toString(),
                name: injectDefaultPlaylistName,
                type: const drift.Value('m3u'),
                contentType: const drift.Value('m3u'),
                filePath: const drift.Value(''),
                epgLink: drift.Value(injectDefaultPlaylistEpg),
                url: drift.Value(injectDefaultPlaylistUrl),
                lastUpdated: drift.Value(now),
                isActive: drift.Value(count == 0),
                isPublic: const drift.Value(false),
              ),
            );
        await driftDb.batch((b) {
          b.insertAll(driftDb.trackDrift, trackCompanions(sourceId, tracks));
        });
      });

      // surface the new playlist in the UI
      await _ref.read(activeSourceProvider.notifier).perform();
      await _ref.read(refreshAllTrackUsecaseProvider).call(NoParams());

      debugPrint(
        'inject: seeded "$injectDefaultPlaylistName" with ${tracks.length} tracks',
      );
    } catch (e) {
      debugPrint('inject: failed, will retry next launch: $e');
    } finally {
      _ref
          .read(injectDefaultPlaylistStatusProvider.notifier)
          .set(InjectDefaultPlaylistStatus.idle);
    }
  }
}

final injectDefaultPlaylistUsecaseProvider =
    Provider<InjectDefaultPlaylistUsecase>((ref) {
  return InjectDefaultPlaylistUsecase(ref);
});
