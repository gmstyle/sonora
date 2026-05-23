import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/player_error_listener.dart';

final _icons = const [Icons.home, Icons.search, Icons.library_music, Icons.download, Icons.settings];

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
      bottomNavigationBar: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            final labels = [l10n.home, l10n.search, l10n.library, l10n.downloads, l10n.settingsLabel];
            return NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(index),
              destinations: [
                for (var i = 0; i < _icons.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: labels[i],
                  ),
              ],
            );
          },
        ),
    );
  }
}
