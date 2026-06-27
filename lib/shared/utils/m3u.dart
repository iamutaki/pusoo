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
import 'package:pusoo/features/track/domain/models/track.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';
import 'package:pusoo/shared/data/playlist_template_reff.dart';
import 'package:pusoo/shared/utils/m3u_parser.dart';

// ponytail: shared by the background flows (auto-refresh, default-playlist
// inject). AddNewPlaylistScreen keeps its own richer fetch (GitHub URL
// rewriting, retries) — extract these into it too only if a 4th caller appears.

const m3uHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
  'Accept': 'text/plain,text/*,*/*',
  'Cache-Control': 'no-cache',
  'Connection': 'keep-alive',
};

/// Downloads the M3U at [url], decodes it, and parses it into [Track]s.
/// Throws on network/parse failure — callers decide whether to swallow it.
Future<List<Track>> fetchAndParseM3u(String url) async {
  final resp = await http
      .get(Uri.parse(url), headers: m3uHeaders)
      .timeout(const Duration(minutes: 2));
  if (resp.statusCode != 200) {
    throw Exception('m3u fetch failed: http ${resp.statusCode}');
  }
  final content = utf8.decode(resp.bodyBytes).replaceFirst('\u{FEFF}', '');
  return M3UParser.parse(content);
}

/// Builds insert-ready [TrackDriftCompanion]s for [tracks], classifying each
/// (live-tv / movie / serie) the same way AddNewPlaylistScreen does.
List<TrackDriftCompanion> trackCompanions(int sourceId, List<Track> tracks) {
  return tracks.map<TrackDriftCompanion>((track) {
    return TrackDriftCompanion(
      sourceId: drift.Value(sourceId),
      title: drift.Value(track.title),
      tvgId: drift.Value(track.tvgId),
      tvgLogo: drift.Value(track.tvgLogo),
      groupTitle: drift.Value(track.groupTitle),
      links: drift.Value(jsonEncode(track.links)),
      kodiProps: drift.Value(jsonEncode(track.kodiProps)),
      extVlcOpts: drift.Value(jsonEncode(track.extVlcOpts)),
      isLiveTv: drift.Value(
        xtreamPlaylistTemplate.liveTvClassifier?.isSatisfiedByAll(track) ??
            false,
      ),
      isMovie: drift.Value(
        xtreamPlaylistTemplate.movieClassifier?.isSatisfiedByAll(track) ??
            false,
      ),
      isTvSerie: drift.Value(
        xtreamPlaylistTemplate.tvSerieClassifier?.isSatisfiedByAll(track) ??
            false,
      ),
    );
  }).toList();
}
