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

/// Feature flag for seeding a default playlist on first launch.
///
/// Disable by flipping to `false` (or wrap in `kDebugMode` to restrict to dev
/// builds). The flag only gates the injection flow at startup; an already-seeded
/// playlist is never auto-removed.
const injectDefaultPlaylistEnabled = true;

/// Looked up by name: if a source with this name already exists, the injection
/// flow is skipped entirely.
const injectDefaultPlaylistName = 'inject_ogie_tv';

const injectDefaultPlaylistUrl =
    'http://ogietv.biz.id:80/get.php?username=maksin&password=123456&type=m3u_plus&output=mpegts';

const injectDefaultPlaylistEpg = '';
