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

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pusoo/shared/extensions/string_ext.dart';
import 'package:pusoo/shared/utils/helpers.dart';
import 'package:pusoo/shared/utils/m3u_parser.dart';
import 'package:pusoo/shared/utils/playlist_name_extractor.dart';
import 'package:pusoo/features/source/domain/entities/source.dart';
import 'package:pusoo/features/source/presentation/providers/active_source_notifier.dart';
import 'package:pusoo/features/track/domain/models/track_filter_query.dart';
import 'package:pusoo/features/tv/presentation/providers/tv_track_count_notifier.dart';
import 'package:pusoo/features/tv/presentation/providers/tv_track_group_titles_notifier.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';
import 'package:pusoo/features/track/domain/models/track.dart';
import 'package:pusoo/shared/data/playlist_template_reff.dart';
import 'package:ulid/ulid.dart';

class AddNewPlaylistScreen extends StatefulHookConsumerWidget {
  final Source source;
  const AddNewPlaylistScreen({required this.source, super.key});

  @override
  ConsumerState<AddNewPlaylistScreen> createState() =>
      _AddNewPlaylistScreenState();
}

class _AddNewPlaylistScreenState extends ConsumerState<AddNewPlaylistScreen> {
  bool isLoading = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(
      text: widget.source.isEmpty ? "" : widget.source.name,
    );
    final urlController = useTextEditingController(
      text: widget.source.isEmpty
          ? ""
          : widget.source.tracks!.first.links.first,
    );
    final epgLinkController = useTextEditingController();

    return FScaffold(
      resizeToAvoidBottomInset: false,
      header: FHeader.nested(
        title: Text("Add Playlist"),
        prefixes: [
          FHeaderAction.back(
            onPress: () {
              context.pop(false);
            },
          ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Gap(10),
          FTextField(
            controller: nameController,
            label: Text("Name"),
            description: Text(
              "If the name is left blank, the playlist name from the URL will be used instead.",
            ),
          ),
          Gap(10),
          FTextField.multiline(
            controller: urlController,
            label: Text("URL/M3U Content"),
            minLines: 6,
            clearable: (TextEditingValue e) => e.text.isNotEmpty,
          ),
          Gap(5),
          FButton(
            style: FButtonStyle.ghost(),
            prefix: Icon(FIcons.clipboardPaste),
            onPress: () async {
              final clipboardData = await Clipboard.getData('text/plain');
              if (clipboardData != null) {
                urlController.text = clipboardData.text ?? '';
                if (context.mounted) {
                  showFlutterToast(
                    message: "Pasted from clipboard",
                    context: context,
                  );
                }
              }
            },
            child: Text("Paste URL/M3U Content"),
          ),
          Gap(10),
          FTextField.multiline(
            controller: epgLinkController,
            label: Text("EPG Link (Optional)"),
            minLines: 2,
            clearable: (TextEditingValue e) => e.text.isNotEmpty,
          ),
          Gap(10),
          SafeArea(
            top: false,
            child: FButton(
              prefix: isLoading ? FProgress.circularIcon() : null,
              onPress: isLoading
                  ? null
                  : () async {
                      if (urlController.text.isEmpty) {
                        showFlutterToast(
                          message: "URL cannot empty",
                          context: context,
                        );
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      final String playlistUlid = Ulid().toString();

                      debugPrint('Playlist Saved!');

                      List<Track> channel = [];
                      String content = "";
                      bool hasError = false;

                      if (urlController.text.isValidUrl()) {
                        try {
                          // Add timeout and retry logic
                          final client = http.Client();
                          http.Response? response;

                          // Retry up to 3 times
                          for (int attempt = 1; attempt <= 3; attempt++) {
                            try {
                              // Handle URLs that might return download instead of content
                              String urlToFetch = urlController.text.trim();
                              
                              // Convert common file hosting URLs to raw content format
                              if (urlToFetch.contains('gist.githubusercontent.com') && 
                                  !urlToFetch.contains('/raw/')) {
                                // Convert GitHub Gist blob URLs to raw URLs
                                urlToFetch = urlToFetch.replaceAll(
                                  RegExp(r'gist\.githubusercontent\.com/[^/]+/[^/]+/blob/'),
                                  'gist.githubusercontent.com/',
                                );
                                if (!urlToFetch.contains('/raw/')) {
                                  final parts = urlToFetch.split('/');
                                  if (parts.length >= 5) {
                                    final user = parts[3];
                                    final gistId = parts[4];
                                    final filename = parts.length > 5 ? parts[5] : 'gistfile1.txt';
                                    urlToFetch = 'https://gist.githubusercontent.com/$user/$gistId/raw/$filename';
                                  }
                                }
                                debugPrint('Converted GitHub Gist URL to: $urlToFetch');
                              } else if (urlToFetch.contains('github.com') && 
                                         urlToFetch.contains('/blob/')) {
                                // Convert GitHub file URLs to raw URLs
                                urlToFetch = urlToFetch.replaceAll('/blob/', '/raw/');
                                debugPrint('Converted GitHub file URL to: $urlToFetch');
                              } else if (urlToFetch.contains('gitlab.com') && 
                                         urlToFetch.contains('/-/blob/')) {
                                // Convert GitLab file URLs to raw URLs
                                urlToFetch = urlToFetch.replaceAll('/-/blob/', '/-/raw/');
                                debugPrint('Converted GitLab file URL to: $urlToFetch');
                              }
                              
                              debugPrint(
                                'Attempt $attempt: Fetching URL: $urlToFetch',
                              );
                              response = await client
                                  .get(
                                    Uri.parse(urlToFetch),
                                      headers: {
                                        'User-Agent':
                                            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
                                        'Accept': 'text/plain,text/*,*/*',
                                        'Accept-Encoding': 'gzip, deflate, br',
                                        'Accept-Language': 'en-US,en;q=0.9',
                                        'Cache-Control': 'no-cache',
                                        'Connection': 'keep-alive',
                                        'X-Requested-With': 'XMLHttpRequest',
                                        'Referer': 'https://gist.githubusercontent.com/',
                                      },
                                  )
                                  .timeout(
                                    const Duration(
                                      minutes: 2,
                                    ), // Increase timeout for large files
                                    onTimeout: () {
                                      throw Exception(
                                        'Connection timeout. File might be too large. Please check your internet connection.',
                                      );
                                    },
                                  );
                              debugPrint(
                                'Response received: ${response.statusCode}, content-length: ${response.contentLength}',
                              );
                              
                              // Check if response is a redirect to download
                              if (response.statusCode == 302 || response.statusCode == 301) {
                                final location = response.headers['location'];
                                if (location != null && location.contains('download')) {
                                  debugPrint('Redirected to download, following redirect...');
                                  response = await client.get(Uri.parse(location));
                                  debugPrint('After redirect: ${response.statusCode}, content-length: ${response.contentLength}');
                                }
                              }
                              
                              // Check if response has download headers
                              final contentDisposition = response.headers['content-disposition'];
                              if (contentDisposition != null && contentDisposition.contains('attachment')) {
                                debugPrint('Response has download headers, but content should still be readable');
                              }
                              
                              break; // Success, exit retry loop
                            } catch (e) {
                              if (attempt == 3) {
                                // Last attempt failed, rethrow the error
                                rethrow;
                              }
                              // Wait before retrying
                              await Future.delayed(
                                Duration(seconds: attempt * 2),
                              );
                              debugPrint('Retry attempt $attempt failed: $e');
                            }
                          }

                          if (response != null && response.statusCode == 200) {
                            try {
                              content = utf8
                                  .decode(response.bodyBytes)
                                  .replaceFirst('\u{FEFF}', '');
                            } catch (_) {
                              content = latin1.decode(response.bodyBytes);
                              debugPrint('Error decoding M3U: $content');
                            }

                            channel = M3UParser.parse(content);
                          } else {
                            throw Exception(
                              'Server returned status code: ${response?.statusCode ?? 'unknown'}',
                            );
                          }

                          client.close();
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                          });

                          hasError = true;

                          String errorMessage = 'Error loading M3U: ';

                          if (e.toString().contains('Network is unreachable')) {
                            errorMessage +=
                                'No internet connection. Please check your network settings and try again.';
                          } else if (e.toString().contains(
                            'Connection failed',
                          )) {
                            errorMessage +=
                                'Cannot connect to server. Please check your internet connection or try again later.';
                          } else if (e.toString().contains('timeout')) {
                            errorMessage +=
                                'Connection timeout. The file might be too large or your connection is slow.';
                          } else if (e.toString().contains('SocketException')) {
                            errorMessage +=
                                'Network error. Please check your internet connection.';
                          } else if (e.toString().contains(
                            'HandshakeException',
                          )) {
                            errorMessage +=
                                'SSL/TLS handshake failed. Please check your network security settings.';
                          } else if (e.toString().contains('FormatException')) {
                            errorMessage +=
                                'Invalid response format. The server returned unexpected data.';
                          } else {
                            errorMessage += e.toString();
                          }

                          // Add specific help for GitHub URLs
                          if (urlController.text.contains(
                            'gist.githubusercontent.com',
                          )) {
                            errorMessage +=
                                '\n\nNote: If this is a GitHub Gist URL, try accessing it in a browser first to ensure it\'s not private.';
                          }

                          if (context.mounted) {
                            showFlutterToast(
                              context: context,
                              message: errorMessage,
                            );
                          }

                          debugPrint('Error loading M3U: $e');
                        }
                      } else {
                        try {
                          content = utf8
                              .decode(urlController.text.trim().codeUnits)
                              .replaceFirst('\u{FEFF}', '');
                        } catch (_) {
                          content = latin1.decode(
                            urlController.text.trim().codeUnits,
                          );
                        }

                        try {
                          channel = M3UParser.parse(content);
                        } catch (e) {
                          hasError = true;
                          setState(() {
                            isLoading = false;
                          });

                          if (context.mounted) {
                            showFlutterToast(
                              context: context,
                              message: 'Error parsing M3U content: $e',
                            );
                          }

                          debugPrint('Error parsing M3U: $e');
                        }
                      }

                      if (context.mounted) {
                        if (hasError) {
                          showFlutterToast(
                            context: context,
                            message: 'Error parsing M3U content',
                          );
                          return;
                        }
                      }

                      final countExpression = driftDb.sourceDrift.id.count();

                      String name = widget.source.isEmpty
                          ? "M3U-${DateTime.now().millisecondsSinceEpoch.toString()}"
                          : nameController.text.trim();

                      if (nameController.text.trim().isEmpty &&
                          urlController.text.isValidUrl()) {
                        final extractedName = PlaylistNameExtractor.fromUrl(
                          urlController.text,
                        ).name;
                        name = extractedName?.isNotEmpty == true
                            ? extractedName!
                            : "M3U-${DateTime.now().millisecondsSinceEpoch.toString()}";
                      }

                      final count =
                          await (driftDb.selectOnly(driftDb.sourceDrift)
                                ..addColumns([countExpression]))
                              .map((row) => row.read(countExpression))
                              .getSingle();

                      final int playlistId = await driftDb
                          .into(driftDb.sourceDrift)
                          .insert(
                            SourceDriftCompanion.insert(
                              ulid: playlistUlid,
                              name: name,
                              type: drift.Value("m3u"),
                              contentType: drift.Value("m3u"),
                              filePath: drift.Value(""),
                              epgLink: drift.Value(
                                epgLinkController.text.trim(),
                              ),
                              url: drift.Value(urlController.text.trim()),
                              // mark as freshly synced so the daily auto-refresh
                              // doesn't immediately re-fetch on the next launch
                              lastUpdated: drift.Value(DateTime.now()),
                              isActive: drift.Value(count == 0),
                              isPublic: drift.Value(
                                widget.source.isPublic ?? false,
                              ),
                            ),
                          );

                      // final isUrlExistOnPlaylisUrlHistory =
                      //     await (driftDb.select(driftDb.sourceDrift)..where(
                      //           (tbl) =>
                      //               tbl.url.equals(urlController.text.trim()),
                      //         ))
                      //         .getSingleOrNull() !=
                      //     null;

                      // TODO : Save history on hive if not exist

                      // if (!isUrlExistOnPlaylisUrlHistory) {
                      //   await driftDb
                      //       .into(driftDb.playlistUrlHistoryDrift)
                      //       .insert(
                      //         PlaylistUrlHistoryDriftCompanion.insert(
                      //           url: drift.Value(urlController.text.trim()),
                      //         ),
                      //       );
                      // }

                      if (channel.isNotEmpty) {
                        await driftDb.batch((batch) {
                          batch.insertAll(
                            driftDb.trackDrift,
                            channel.map<TrackDriftCompanion>((Track track) {
                              return TrackDriftCompanion(
                                sourceId: drift.Value(playlistId),
                                title: drift.Value(track.title),
                                tvgId: drift.Value(track.tvgId),
                                tvgLogo: drift.Value(track.tvgLogo),
                                groupTitle: drift.Value(track.groupTitle),
                                links: drift.Value(jsonEncode(track.links)),
                                kodiProps: drift.Value(
                                  jsonEncode(track.kodiProps),
                                ),
                                extVlcOpts: drift.Value(
                                  jsonEncode(track.extVlcOpts),
                                ),
                                isLiveTv: drift.Value(
                                  xtreamPlaylistTemplate.liveTvClassifier
                                          ?.isSatisfiedByAll(track) ??
                                      false,
                                ),
                                isMovie: drift.Value(
                                  xtreamPlaylistTemplate.movieClassifier
                                          ?.isSatisfiedByAll(track) ??
                                      false,
                                ),
                                isTvSerie: drift.Value(
                                  xtreamPlaylistTemplate.tvSerieClassifier
                                          ?.isSatisfiedByAll(track) ??
                                      false,
                                ),
                              );
                            }).toList(),
                          );
                        });

                        if (count == 0) {
                          ref.read(activeSourceProvider.notifier).perform();
                          ref
                              .read(tvTrackCountProvider.notifier)
                              .perform(TrackFilterQuery(isLiveTv: true));
                          ref
                              .read(tvTrackGroupTitlesProvider.notifier)
                              .perform(TrackFilterQuery(isLiveTv: true));
                        }
                      }

                      if (context.mounted) {
                        setState(() {
                          isLoading = false;
                        });

                        context.pop(true);
                      }
                    },
              child: Text("Save"),
            ),
          ),
          Gap(10),
        ],
      ),
    );
  }
}
