import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/nav_now_playing.dart';
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
];

class TabletShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const TabletShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;

    // Bound rail width (Row leaves non-flex children unbounded horizontally).
    final railWidth = NavigationRailTheme.of(context).minWidth ?? 72.0;

    return Scaffold(
      body: Row(
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              width: railWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected:
                          (index) => navigationShell.goBranch(index),
                      labelType: NavigationRailLabelType.selected,
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: SonoraLogo.icon(36),
                      ),
                      destinations: [
                        for (var i = 0; i < _icons.length; i++)
                          NavigationRailDestination(
                            icon: Icon(_icons[i]),
                            label: Text(
                              _getLabel(AppLocalizations.of(context)!, i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _TabletSettingsEntry(),
                  const NavNowPlaying(expanded: false),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
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

class _TabletSettingsEntry extends StatelessWidget {
  const _TabletSettingsEntry();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = AppLocalizations.of(context)!.settingsLabel;
    final isSelected = GoRouterState.of(context).uri.path == '/settings';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Tooltip(
        message: label,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor:
                  isSelected
                      ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                      : null,
              foregroundColor:
                  isSelected ? colorScheme.primary : colorScheme.onSurface,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => context.push('/settings'),
            child: const Icon(LucideIcons.settings),
          ),
        ),
      ),
    );
  }
}

String _getLabel(AppLocalizations l10n, int index) {
  return [l10n.home, l10n.search, l10n.library, l10n.downloads][index];
}
