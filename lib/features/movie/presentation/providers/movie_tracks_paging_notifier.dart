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

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pusoo/features/movie/presentation/providers/movie_tracks_filter_notifier.dart';
import 'package:pusoo/features/track/presentation/providers/track_notifier.dart';
import 'package:pusoo/features/track/domain/models/track.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'movie_tracks_paging_notifier.g.dart';

@riverpod
class MovieTracksPagingNotifier extends _$MovieTracksPagingNotifier {
  static const pageSize = 20;

  @override
  PagingController<int, Track> build() {
    final controller = PagingController<int, Track>(
      getNextPageKey: (state) {
        if (state.pages == null || state.pages!.isEmpty) return 0;
        if (!state.hasNextPage) return null;

        final lastPage = state.pages!.last;
        // a page smaller than pageSize means we've reached the end
        if (lastPage.length < pageSize) return null;

        return lastPage.last.id;
      },
      fetchPage: (pageKey) async {
        final filterState = ref.read(movieTracksFilterProvider);

        try {
          await ref
              .read(tracksProvider.notifier)
              .perform(filterState.copyWith(cursor: pageKey, limit: pageSize));

          return ref.read(tracksProvider).value ?? [];
        } catch (e) {
          rethrow;
        }
      },
    );

    ref.onDispose(() {
      controller.dispose();
    });

    return controller;
  }

  void refresh() {
    state.refresh();
  }
}
