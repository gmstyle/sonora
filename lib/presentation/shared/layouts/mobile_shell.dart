import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/player_error_listener.dart';

const _destinations = (
  icons: [Icons.home, Icons.search, Icons.library_music, Icons.download, Icons.settings],
  labels: ['Home', 'Search', 'Library', 'Downloads', 'Settings'],
);

class MobileShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MobileShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: isPlayerActive ? 72.0 : 0.0),
            child: navigationShell,
          ),
          const PlayerSheet(),
          const PlayerErrorListener(),
          const ActionFeedbackListener(),
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
