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

import 'package:drift/drift.dart';
import 'package:pusoo/features/track/domain/models/track.dart';
import 'package:pusoo/shared/data/datasources/local/drift/drift_database.dart';

extension TrackDriftDataExt on TrackDriftData {
  Track toEntity() {
    // fromDrift(TrackDriftData trackDrift) {
    final json = toJson();

    void convertStringToList(String fieldName) {
      final dynamic fieldValue = json[fieldName];
      if (fieldValue is String) {
        if (fieldValue.isEmpty) {
          json[fieldName] = [];
        } else {
          try {
            final decoded = jsonDecode(fieldValue);
            if (decoded is List) {
              json[fieldName] = decoded;
            } else {
              json[fieldName] = [decoded];
            }
          } catch (e) {
            json[fieldName] = [fieldValue];
          }
        }
      } else if (fieldValue is! List) {
        json[fieldName] = [];
      }
    }

    convertStringToList('links');
    convertStringToList('extVlcOpts');
    convertStringToList('kodiProps');
    convertStringToList('httpHeaders');

    return Track.fromJson(json);
  }
}

extension TrackTypedResultExt on TypedResult {
  Track toEntity() {
    dynamic json = readTable(driftDb.trackDrift).toJson();

    final playlistJson = readTable(driftDb.sourceDrift).toJson();

    void convertStringToList(String fieldName) {
      final dynamic fieldValue = json[fieldName];
      if (fieldValue is String) {
        if (fieldValue.isEmpty) {
          json[fieldName] = [];
        } else {
          try {
            final decoded = jsonDecode(fieldValue);
            if (decoded is List) {
              json[fieldName] = decoded;
            } else {
              json[fieldName] = [decoded];
            }
          } catch (e) {
            json[fieldName] = [fieldValue];
          }
        }
      } else if (fieldValue is! List) {
        json[fieldName] = [];
      }
    }

    convertStringToList('links');
    convertStringToList('extVlcOpts');
    convertStringToList('kodiProps');

    json['playlist'] = playlistJson;

    return Track.fromJson(json);
  }
}
