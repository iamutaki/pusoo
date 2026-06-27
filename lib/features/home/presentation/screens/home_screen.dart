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
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pusoo/features/explore/presentation/screens/explore_screen.dart';
import 'package:pusoo/features/movie/presentation/screens/movie_screen.dart';
import 'package:pusoo/features/playlist/domain/usecases/inject_default_playlist_usecase.dart';
import 'package:pusoo/features/serie/presentation/screens/serie_screen.dart';
import 'package:pusoo/features/setting/presentation/screens/setting_screen.dart';
import 'package:pusoo/features/tv/presentation/screens/tv_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isInjecting =
        ref.watch(injectDefaultPlaylistStatusProvider) ==
            InjectDefaultPlaylistStatus.injecting;
    if (isInjecting) {
      // first-run: cover the whole UI while the default playlist is seeded
      return const _DefaultPlaylistLoadingGate();
    }

    final orientation = MediaQuery.of(context).orientation;
    final isPotrait = orientation == Orientation.portrait;

    final scaffold = FScaffold(
      resizeToAvoidBottomInset: false,
      sidebar: isPotrait
          ? SizedBox.shrink()
          : FSidebar(
              children: [
                FSidebarGroup(
                  children: [
                    FSidebarItem(
                      icon: const Icon(FIcons.compass),
                      label: const Text('Explore'),
                      selected: selectedIndex == 0,
                      onPress: () {
                        setState(() {
                          selectedIndex = 0;
                        });
                      },
                    ),
                    FSidebarItem(
                      icon: const Icon(FIcons.monitor),
                      selected: selectedIndex == 1,
                      label: const Text('Live TV'),
                      onPress: () {
                        setState(() {
                          selectedIndex = 1;
                        });
                      },
                    ),
                    FSidebarItem(
                      icon: const Icon(FIcons.monitorPlay),
                      selected: selectedIndex == 2,
                      label: const Text('Movies'),
                      onPress: () {
                        setState(() {
                          selectedIndex = 2;
                        });
                      },
                    ),
                    FSidebarItem(
                      icon: const Icon(FIcons.monitorCheck),
                      selected: selectedIndex == 3,
                      label: const Text('TV Series'),
                      onPress: () {
                        setState(() {
                          selectedIndex = 3;
                        });
                      },
                    ),
                    FSidebarItem(
                      icon: const Icon(FIcons.settings),
                      selected: selectedIndex == 4,
                      label: const Text('Settings'),
                      onPress: () {
                        setState(() {
                          selectedIndex = 4;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
      footer: isPotrait
          ? FBottomNavigationBar(
              onChange: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              children: [
                FBottomNavigationBarItem(
                  icon: Icon(
                    FIcons.compass,
                    color: selectedIndex == 0
                        ? context.theme.colors.primary
                        : null,
                  ),
                  label: Text(
                    'Explore',
                    style: TextStyle(
                      color: selectedIndex == 0
                          ? context.theme.colors.primary
                          : null,
                      fontWeight: selectedIndex == 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(
                    FIcons.monitor,
                    color: selectedIndex == 1
                        ? context.theme.colors.primary
                        : null,
                  ),
                  label: Text(
                    'Live TV',
                    style: TextStyle(
                      color: selectedIndex == 1
                          ? context.theme.colors.primary
                          : null,
                      fontWeight: selectedIndex == 1 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(
                    FIcons.monitorPlay,
                    color: selectedIndex == 2
                        ? context.theme.colors.primary
                        : null,
                  ),
                  label: Text(
                    'Movies',
                    style: TextStyle(
                      color: selectedIndex == 2
                          ? context.theme.colors.primary
                          : null,
                      fontWeight: selectedIndex == 2 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(
                    FIcons.monitorCheck,
                    color: selectedIndex == 3
                        ? context.theme.colors.primary
                        : null,
                  ),
                  label: Text(
                    'TV Series',
                    style: TextStyle(
                      color: selectedIndex == 3
                          ? context.theme.colors.primary
                          : null,
                      fontWeight: selectedIndex == 3 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(
                    FIcons.settings,
                    color: selectedIndex == 4
                        ? context.theme.colors.primary
                        : null,
                  ),
                  label: Text(
                    'Settings',
                    style: TextStyle(
                      color: selectedIndex == 4
                          ? context.theme.colors.primary
                          : null,
                      fontWeight: selectedIndex == 4 ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox.shrink(),
      child: IndexedStack(
        index: selectedIndex,
        children: [
          ExploreScreen(),
          TvScreen(),
          MovieScreen(),
          SerieScreen(),
          SettingScreen(),
        ],
      ),
    );

    return scaffold;
  }
}

/// Full-screen, opaque first-run gate shown while the default playlist is being
/// seeded. Replaces the whole HomeScreen so nothing behind it is visible or
/// interactable — a clean splash-like cover, not a peek-through overlay.
class _DefaultPlaylistLoadingGate extends StatelessWidget {
  const _DefaultPlaylistLoadingGate();

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      resizeToAvoidBottomInset: false,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: SvgPicture.asset(
                    'assets/icon.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                const Gap(24),
                FProgress.circularIcon(),
                const Gap(16),
                Text(
                  'Menyiapkan playlist default...',
                  textAlign: TextAlign.center,
                  style: context.theme.typography.base,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
