import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/branch_fade_transition.dart';
import '../widgets/player_error_listener.dart';
import '../widgets/sonora_logo.dart';

final _icons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
  LucideIcons.settings,
];

class TabletShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const TabletShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SonoraLogo.icon(36),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            destinations: [
              for (var i = 0; i < _icons.length; i++)
                NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  label: Text(_getLabel(AppLocalizations.of(context)!, i)),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: isPlayerActive ? 72.0 : 0.0),
                  child: BranchFadeTransition(navigationShell: navigationShell),
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
