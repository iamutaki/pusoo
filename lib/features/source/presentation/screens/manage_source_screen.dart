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
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pusoo/shared/utils/helpers.dart';
import 'package:pusoo/shared/utils/usecase.dart';
import 'package:pusoo/features/source/presentation/providers/active_source_notifier.dart';
import 'package:pusoo/features/track/presentation/providers/track_providers.dart';
import 'package:pusoo/router.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';
import 'package:drift/drift.dart' as drift;

class ManageSourceScreen extends ConsumerStatefulWidget {
  const ManageSourceScreen({super.key});

  @override
  ConsumerState<ManageSourceScreen> createState() => _ManageSourceScreenState();
}

class _ManageSourceScreenState extends ConsumerState<ManageSourceScreen> {
  List<SourceDriftData> playlist = [];

  void loadPlaylist() async {
    final allPlaylists = await driftDb.select(driftDb.sourceDrift).get();

    setState(() {
      playlist = allPlaylists;
    });
  }

  void removeAllPlaylist() async {
    // Hapus semua isi tabel 'playlist'
    await driftDb.delete(driftDb.sourceDrift).go();
    await driftDb.delete(driftDb.trackDrift).go();

    // invalidate cached active source + reload the home track lists, otherwise
    // the deleted active playlist's channels linger until a manual refresh
    await ref.read(activeSourceProvider.notifier).perform();
    ref.read(refreshAllTrackUsecaseProvider).call(NoParams());

    loadPlaylist();
  }

  @override
  void initState() {
    super.initState();

    loadPlaylist();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: Text("Manage Sources"),
        prefixes: [
          FHeaderAction.back(
            onPress: () {
              context.pop(false);
            },
          ),
        ],
        suffixes: [
          FHeaderAction(
            icon: Icon(FIcons.shredder),
            onPress: () async {
              await showFDialog(
                context: context,
                builder: (context, style, animation) => FDialog(
                  animation: animation,
                  direction: Axis.horizontal,
                  title: const Text('Truncate playlist'),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(10),
                      Text(
                        "WARNING!",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "This action will permanently delete all playlists. You can't undo this.",
                      ),
                    ],
                  ),
                  actions: [
                    FButton(
                      style: FButtonStyle.outline(),
                      onPress: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                    FButton(
                      style: FButtonStyle.destructive(),
                      onPress: () async {
                        removeAllPlaylist();
                        context.pop();

                        showFlutterToast(
                          message: "All playlist deleted",
                          context: context,
                        );
                      },
                      child: const Text('Yes, Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      child: Column(
        children: [
          Builder(
            builder: (context) {
              return Flexible(
                flex: 3,
                child: FButton(
                  style: FButtonStyle.outline(),
                  onPress: () async {
                    final result = await context.pushNamed(
                      RouteName.addNewSource.name,
                    );

                    if (result is bool && result) {
                      // reload available
                      loadPlaylist();

                      if (context.mounted) {
                        showFlutterToast(
                          context: context,
                          message: "Playlist saved",
                        );

                        ref
                            .read(refreshAllTrackUsecaseProvider)
                            .call(NoParams());
                      }
                    }
                  },
                  prefix: Icon(FIcons.plus),
                  child: Text("Add new source"),
                ),
              );
            },
          ),
          Gap(10),
          Expanded(
            child: Builder(
              builder: (context) {
                if (playlist.isEmpty) {
                  return Center(child: Text("No Data"));
                } else {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                        ...playlist.map((e) {
                          return FTile(
                            prefix: SizedBox(
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: e.isActive
                                      ? context.theme.colors.primary
                                      : context.theme.colors.destructive,
                                ),
                              ),
                            ),
                            title: Text(
                              e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            details: Text("Playlist"),
                            subtitle: Text(
                              e.url ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            suffix: Icon(FIcons.chevronRight),
                            onPress: e.isActive
                                ? () {
                                    showFlutterToast(
                                      context: context,
                                      message:
                                          "This is the active playlist. Please select another.",
                                    );
                                  }
                                : () {
                                    showFDialog(
                                      context: context,
                                      builder: (context, style, animation) => FDialog(
                                        animation: animation,
                                        direction: Axis.horizontal,
                                        title: const Text('Select an action'),
                                        body: Column(
                                          children: [
                                            Text(
                                              "Please choose an action to perform on this playlist.",
                                            ),
                                            FDivider(
                                              style: (style) => style.copyWith(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 5,
                                                ),
                                              ),
                                            ),
                                            FItemGroup(
                                              children: [
                                                FItem(
                                                  prefix: Icon(
                                                    FIcons.circleDashed,
                                                  ),
                                                  title: Text(
                                                    "Set as active playlist",
                                                  ),
                                                  suffix: Icon(FIcons.check),
                                                  onPress: () async {
                                                    // update data old selected as false
                                                    await (driftDb.update(
                                                          driftDb.sourceDrift,
                                                        )..where(
                                                          (tbl) => tbl.isActive
                                                              .equals(true),
                                                        ))
                                                        .write(
                                                          const SourceDriftCompanion(
                                                            isActive:
                                                                drift.Value(
                                                                  false,
                                                                ),
                                                          ),
                                                        );

                                                    // update data old selected as false
                                                    await (driftDb.update(
                                                          driftDb.sourceDrift,
                                                        )..where(
                                                          (tbl) => tbl.id
                                                              .equals(e.id),
                                                        ))
                                                        .write(
                                                          const SourceDriftCompanion(
                                                            isActive:
                                                                drift.Value(
                                                                  true,
                                                                ),
                                                          ),
                                                        );

                                                    loadPlaylist();

                                                    // invalidate cached active source + reload home lists so Home
                                                    // switches to the new active playlist immediately
                                                    await ref
                                                        .read(
                                                          activeSourceProvider
                                                              .notifier,
                                                        )
                                                        .perform();
                                                    ref
                                                        .read(
                                                          refreshAllTrackUsecaseProvider,
                                                        )
                                                        .call(NoParams());

                                                    if (context.mounted) {
                                                      context.pop();

                                                      // showFToast(
                                                      //   context: context,
                                                      //   alignment:
                                                      //       FToastAlignment
                                                      //           .topCenter,
                                                      //   title: Text(
                                                      //     "Set ${e.name} as active playlist",
                                                      //   ),
                                                      // );
                                                      showFlutterToast(
                                                        context: context,
                                                        message:
                                                            "Set ${e.name} as active playlist",
                                                      );
                                                    }
                                                  },
                                                ),
                                                FItem(
                                                  prefix: Icon(
                                                    FIcons.circleDashed,
                                                  ),
                                                  title: Text(
                                                    "Remove from playlist",
                                                  ),
                                                  suffix: Icon(FIcons.trash),
                                                  onPress: () async {
                                                    final wasActive = e.isActive;

                                                    // delete source row first
                                                    await (driftDb.delete(
                                                          driftDb.sourceDrift,
                                                        )..where(
                                                          (tbl) => tbl.id
                                                              .equals(e.id),
                                                        ))
                                                        .go();

                                                    // then its tracks
                                                    await (driftDb.delete(
                                                          driftDb.trackDrift,
                                                        )..where(
                                                          (tbl) => tbl.sourceId
                                                              .equals(e.id),
                                                        ))
                                                        .go();

                                                    // if we removed the active
                                                    // playlist, promote another so
                                                    // the home isn't left empty
                                                    if (wasActive) {
                                                      final remaining =
                                                          await driftDb
                                                              .select(
                                                                driftDb
                                                                    .sourceDrift,
                                                              )
                                                              .get();
                                                      if (remaining.isNotEmpty) {
                                                        await (driftDb.update(
                                                                  driftDb
                                                                      .sourceDrift,
                                                                )..where(
                                                                  (t) => t.id
                                                                      .equals(
                                                                        remaining
                                                                            .first
                                                                            .id,
                                                                      ),
                                                                ))
                                                            .write(
                                                              SourceDriftCompanion(
                                                                isActive:
                                                                    drift.Value(
                                                                  true,
                                                                ),
                                                              ),
                                                            );
                                                      }
                                                    }

                                                    // invalidate cached active
                                                    // source + reload home lists
                                                    await ref
                                                        .read(
                                                          activeSourceProvider
                                                              .notifier,
                                                        )
                                                        .perform();
                                                    ref
                                                        .read(
                                                          refreshAllTrackUsecaseProvider,
                                                        )
                                                        .call(NoParams());

                                                    loadPlaylist();

                                                    if (context.mounted) {
                                                      context.pop();

                                                      // showFToast(
                                                      //   context: context,
                                                      //   alignment:
                                                      //       FToastAlignment
                                                      //           .topCenter,
                                                      //   title: Text(
                                                      //     "Removed ${e.name} from playlist",
                                                      //   ),
                                                      // );
                                                      showFlutterToast(
                                                        context: context,
                                                        message:
                                                            "Removed ${e.name} from playlist",
                                                      );
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
                                  },
                          );
                        }),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
