import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/player_error_listener.dart';
import '../widgets/sonora_logo.dart';

const _icons = [
  Icons.home,
  Icons.search,
  Icons.library_music,
  Icons.download,
  Icons.settings,
];

class WideShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const WideShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  DrawerHeader(child: const SonoraLogo.full(44)),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < _icons.length; i++)
                          ListTile(
                            selected: navigationShell.currentIndex == i,
                            selectedTileColor:
                                Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                            leading: Icon(_icons[i]),
                            title: Text(
                              _getLabel(AppLocalizations.of(context)!, i),
                            ),
                            onTap: () => navigationShell.goBranch(i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Stack(
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
          ),
        ],
      ),
    );
  }
}

String _getLabel(AppLocalizations l10n, int index) {
  return [
    l10n.home,
    l10n.search,
    l10n.library,
    l10n.downloads,
    l10n.settingsLabel,
  ][index];
}
