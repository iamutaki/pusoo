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

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:pusoo/shared/utils/theme_app.dart';
import 'package:pusoo/shared/utils/helpers.dart';
import 'package:pusoo/features/source/presentation/providers/active_source_notifier.dart';
import 'package:pusoo/features/track/domain/usecases/auto_refresh_active_source_usecase.dart';
import 'package:pusoo/features/track/domain/models/track_filter_query.dart';
import 'package:pusoo/features/tv/presentation/providers/tv_track_count_notifier.dart';
import 'package:pusoo/features/tv/presentation/providers/tv_track_group_titles_notifier.dart';
import 'package:pusoo/features/tv/presentation/providers/tv_tracks_paging_notifier.dart';
import 'package:pusoo/features/tv/presentation/providers/tv_tracks_filter_notifier.dart';
import 'package:pusoo/features/tv/presentation/widgets/tvg_logo_viewer.dart';
import 'package:pusoo/router.dart';
import 'package:pusoo/features/track/domain/models/track.dart';

class TvScreen extends StatefulHookConsumerWidget {
  const TvScreen({super.key});

  @override
  ConsumerState<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends ConsumerState<TvScreen> {
  final Debouncer _debouncer = Debouncer();
  final Duration _debounceDuration = const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeSourceProvider.notifier).perform();

      ref
          .read(tvTrackGroupTitlesProvider.notifier)
          .perform(TrackFilterQuery(isLiveTv: true));

      ref
          .read(tvTrackCountProvider.notifier)
          .perform(TrackFilterQuery(isLiveTv: true));
    });
  }

  Widget _buildSearch(TextEditingController controller) {
    final asyncCountTrack = ref.watch(tvTrackCountProvider);

    return FTextField(
      controller: controller,
      hint: asyncCountTrack.hasValue
          ? "Find a channel - ${NumberFormat.decimalPattern().format(asyncCountTrack.value)} available"
          : "Find a channel...",
      clearable: (e) => e.text.isNotEmpty,
      onChange: (String value) {
        _debouncer.debounce(
          duration: _debounceDuration,
          onDebounce: () async {
            ref.read(tvTracksFilterProvider.notifier).changeTitle(value);
            ref.read(tvTracksPagingProvider).refresh();
          },
        );
      },
    );
  }

  void openDialogChangePlaylist(BuildContext context) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        direction: Axis.horizontal,
        title: const Text('Change playlist'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FDivider(
              style: (style) =>
                  style.copyWith(padding: EdgeInsets.symmetric(vertical: 5)),
            ),
            FItemGroup(
              children: [
                FItem(
                  prefix: Icon(FIcons.circleDashed),
                  title: Text("IPTV-ORG ID"),
                  suffix: Icon(FIcons.check),
                  onPress: () async {
                    if (context.mounted) {
                      context.pop();
                    }
                  },
                ),
                FItem(
                  prefix: Icon(FIcons.circleDashed),
                  title: Text("IPTV-ORG MY"),
                  onPress: () async {
                    // loadPlaylist();

                    if (context.mounted) {
                      context.pop();
                    }
                  },
                ),
                FItem(
                  prefix: Icon(FIcons.circleDashed),
                  title: Text("IPTV-ORG PE"),
                  onPress: () async {
                    if (context.mounted) {
                      context.pop();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          FButton(
            style: FButtonStyle.outline(),
            onPress: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool listViewMode = true;

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isPotrait = orientation == Orientation.portrait;

    final searchController = useTextEditingController();
    final isRefreshing = useState(false);

    final asyncGroupTitles = ref.watch(tvTrackGroupTitlesProvider);

    final asyncActivePlaylist = ref.watch(activeSourceProvider);

    MediaQuery.of(context).orientation == Orientation.portrait;

    return FScaffold(
      childPad: false,
      resizeToAvoidBottomInset: false,
      header: FHeader(
        title: Row(
          children: [
            const Text('TV'),
            Gap(10),
            isPotrait
                ? Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        openDialogChangePlaylist(context);
                      },
                      child: SizedBox(
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            border: BoxBorder.all(
                              color: context.theme.colors.border,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(3),
                            child: Row(
                              children: [
                                Gap(2),
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.theme.colors.primary,
                                    ),
                                  ),
                                ),
                                Gap(5),
                                Expanded(
                                  child: asyncActivePlaylist.when(
                                    data: (data) => Text(
                                      data!.name ?? "No Name",
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: context
                                            .theme
                                            .typography
                                            .sm
                                            .fontSize,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    error: (e, s) => Text(
                                      "Playlist not available",
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: context
                                            .theme
                                            .typography
                                            .xs
                                            .fontSize,
                                        fontWeight: FontWeight.w600,
                                        color: context.theme.colors.disable(
                                          context.theme.colors.foreground,
                                        ),
                                      ),
                                    ),
                                    loading: () => Text(
                                      "Fetching playlist...",
                                      style: TextStyle(
                                        fontSize: CustomThemeData.fontSize.xs1,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                                Icon(FIcons.antenna),
                                Gap(3),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Flexible(child: _buildSearch(searchController)),
          ],
        ),
        suffixes: [
          FHeaderAction(
            icon: isRefreshing.value
                ? FProgress.circularIcon()
                : Icon(FIcons.refreshCw),
            // manual re-sync of the active playlist (bypasses the 24h throttle)
            onPress: isRefreshing.value
                ? null
                : () async {
                    isRefreshing.value = true;
                    final count = await ref
                        .read(autoRefreshActiveSourceUsecaseProvider)
                        .call(force: true);
                    if (!context.mounted) return;
                    isRefreshing.value = false;
                    showFlutterToast(
                      context: context,
                      message: count == null
                          ? "Gagal refresh / tidak ada source aktif"
                          : "Playlist di-refresh ($count channel)",
                    );
                  },
          ),
          !isPotrait
              ? FHeaderAction(
                  icon: Icon(FIcons.antenna),
                  onPress: () {
                    openDialogChangePlaylist(context);
                  },
                )
              : SizedBox.shrink(),
          FHeaderAction(
            icon: Icon(listViewMode ? FIcons.grid2x2 : FIcons.rows3),
            onPress: () async {
              setState(() {
                listViewMode = !listViewMode;
              });
            },
          ),
          FHeaderAction(
            icon: Icon(FIcons.menu),
            onPress: () async {
              showFSheet(
                context: context,
                side: FLayout.ltr,
                useRootNavigator: true,
                useSafeArea: false,
                mainAxisMaxRatio: null,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  maxHeight: double.infinity,
                ),
                barrierDismissible: true,
                draggable: true,
                builder: (context) => FScaffold(
                  child: SafeArea(
                    child: Column(
                      spacing: 5,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Gap(10),
                            Text(
                              "Category",
                              style: context.theme.typography.base.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        FDivider(
                          style: (style) => style.copyWith(
                            padding: EdgeInsets.symmetric(vertical: 5),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: asyncGroupTitles.when(
                              data: (data) {
                                return Column(
                                  spacing: 0,
                                  children: [
                                    FItem(
                                      prefix: Icon(FIcons.tags),
                                      title: Text("All Channels"),
                                      suffix: Icon(FIcons.chevronRight),
                                      onPress: () {
                                        ref
                                            .read(
                                              tvTracksFilterProvider.notifier,
                                            )
                                            .changeGroupTitle(null);
                                        ref
                                            .read(tvTracksPagingProvider)
                                            .refresh();

                                        context.pop();
                                      },
                                    ),
                                    ...data!.map(
                                      (e) => FItem(
                                        prefix: Icon(FIcons.tag),
                                        title: Text(
                                          e.trim().isEmpty
                                              ? "Unknown"
                                              : e.trim(),
                                        ),
                                        suffix: Icon(FIcons.chevronRight),
                                        onPress: () {
                                          ref
                                              .read(
                                                tvTracksFilterProvider.notifier,
                                              )
                                              .changeGroupTitle(e);
                                          ref
                                              .read(tvTracksPagingProvider)
                                              .refresh();

                                          context.pop();
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                              error: (e, f) => SizedBox.shrink(),
                              loading: () => SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      child: Column(
        spacing: 0,
        children: [
          Builder(
            builder: (context) {
              return isPotrait
                  ? Column(children: [_buildSearch(searchController), Gap(10)])
                  : SizedBox.shrink();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              child: PagingListener(
                controller: ref.watch(tvTracksPagingProvider),
                builder: (BuildContext context, state, fetchNextPage) =>
                    listViewMode
                    ? PagedListView(
                        padding: EdgeInsets.zero,
                        state: state,
                        fetchNextPage: fetchNextPage,
                        builderDelegate: PagedChildBuilderDelegate(
                          itemBuilder: (context, Track item, index) => Column(
                            children: [
                              FItem(
                                onPress: () {
                                  context.pushNamed(
                                    RouteName.videoPlayer.name,
                                    extra: item,
                                    queryParameters: {"isLiveStream": "true"},
                                  );
                                },
                                prefix: TvgLogoViewer(
                                  size: 50,
                                  track: item,
                                  showLabel: false,
                                ),
                                title: Text(item.title.trim(), maxLines: 2),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    item.groupTitle.trim().isNotEmpty
                                        ? Text(item.groupTitle.trim())
                                        : Text("Unknown"),
                                    item.tvgId.trim().isNotEmpty
                                        ? Text(item.tvgId.trim(), maxLines: 2)
                                        : Text("@tvg-id: n/a"),
                                  ],
                                ),
                                suffix: Icon(FIcons.play),
                              ),
                              FDivider(
                                style: (style) => style.copyWith(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  width: 1,
                                ),
                              ),
                            ],
                          ),
                          firstPageProgressIndicatorBuilder: (context) =>
                              FProgress.circularIcon(),
                          newPageProgressIndicatorBuilder: (context) =>
                              FProgress.circularIcon(),
                        ),
                      )
                    : PagedGridView(
                        padding: EdgeInsets.zero,
                        state: state,
                        fetchNextPage: fetchNextPage,
                        builderDelegate: PagedChildBuilderDelegate(
                          itemBuilder: (context, Track item, index) =>
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed(
                                    RouteName.videoPlayer.name,
                                    extra: item,
                                  );
                                },
                                child: TvgLogoViewer(
                                  // size: 50,
                                  track: item,
                                  showLabel: true,
                                ),
                              ),
                          firstPageProgressIndicatorBuilder: (context) =>
                              FProgress.circularIcon(),
                          newPageProgressIndicatorBuilder: (context) =>
                              FProgress.circularIcon(),
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isPotrait ? 4 : 8,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5,
                        ),
                      ),
              ),
              onRefresh: () async {
                searchController.text = "";

                ref.read(tvTracksFilterProvider.notifier).reset();
                ref.read(tvTracksPagingProvider).refresh();
              },
            ),
          ),
        ],
      ),
    );
  }
}
