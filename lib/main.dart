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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pusoo/features/track/domain/usecases/auto_refresh_active_source_usecase.dart';
import 'package:pusoo/router.dart';
import 'package:pusoo/shared/utils/usecase.dart';
// import 'package:video_player_media_kit/video_player_media_kit.dart';

// import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // inisialisasi binding
  // WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  // VideoPlayerMediaKit.ensureInitialized(
  //   android: true,
  //   // windows: true,
  //   // linux: true,
  // );

  // Wajib: inisialisasi MediaKit sebelum dipakai
  // MediaKit.ensureInitialized();

  // SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.portraitUp,
  //   DeviceOrientation.portraitDown,
  // ]);

  final container = ProviderContainer();

  // Daily auto-refresh of the active playlist (throttled to once/24h, silent on
  // failure — the UI keeps showing existing DB tracks while this runs).
  unawaited(
    container.read(autoRefreshActiveSourceUsecaseProvider).call(NoParams()),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: Application()),
  );
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  @override
  void initState() {
    super.initState();

    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  @override
  Widget build(BuildContext context) {
    final theme = FThemes.zinc.dark;

    return MaterialApp.router(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      builder: (_, child) => FTheme(data: theme, child: child!),
      theme: theme.toApproximateMaterialTheme(),
      routerConfig: router,
    );
  }
}
