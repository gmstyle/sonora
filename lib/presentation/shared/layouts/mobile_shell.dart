import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/player/mini_player.dart';

const _destinations = (
  icons: [Icons.home, Icons.search, Icons.library_music, Icons.download, Icons.settings],
  labels: ['Home', 'Search', 'Library', 'Downloads', 'Settings'],
);

class MobileShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: [
          for (var i = 0; i < _destinations.icons.length; i++)
            NavigationDestination(
              icon: Icon(_destinations.icons[i]),
              label: _destinations.labels[i],
            ),
        ],
      ),
    );
  }
}
