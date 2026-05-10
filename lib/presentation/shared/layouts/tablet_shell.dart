import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/player/player_sheet.dart';

const _icons = [Icons.home, Icons.search, Icons.library_music, Icons.download, Icons.settings];
const _labels = ['Home', 'Search', 'Library', 'Downloads', 'Settings'];

class TabletShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const TabletShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.music_note, size: 32),
            ),
            destinations: [
              for (var i = 0; i < _icons.length; i++)
                NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  label: Text(_labels[i]),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Stack(
              children: [
                navigationShell,
                const PlayerSheet(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
