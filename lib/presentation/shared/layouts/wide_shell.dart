import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/player/mini_player.dart';

const _icons = [Icons.home, Icons.search, Icons.library_music, Icons.download, Icons.settings];
const _labels = ['Home', 'Search', 'Library', 'Downloads', 'Settings'];

class WideShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const WideShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  DrawerHeader(
                    child: Row(
                      children: [
                        Icon(Icons.music_note,
                            size: 28, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Sonora',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < _icons.length; i++)
                          ListTile(
                            selected: navigationShell.currentIndex == i,
                            selectedTileColor:
                                Theme.of(context).colorScheme.secondaryContainer,
                            leading: Icon(_icons[i]),
                            title: Text(_labels[i]),
                            onTap: () => navigationShell.goBranch(i),
                          ),
                      ],
                    ),
                  ),
                  const MiniPlayer(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
