import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/nav_now_playing.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/branch_fade_transition.dart';
import '../widgets/player_error_listener.dart';
import '../widgets/sonora_logo.dart';
import '../widgets/scale_button.dart';

final _icons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
  LucideIcons.settings,
];

class WideShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const WideShell({super.key, required this.navigationShell});

  @override
  ConsumerState<WideShell> createState() => _WideShellState();
}

class _WideShellState extends ConsumerState<WideShell> {
  @override
  Widget build(BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;
    final colorScheme = Theme.of(context).colorScheme;
    final targetWidth = isCollapsed ? 72.0 : 240.0;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: targetWidth,
            child: Material(
              color: colorScheme.surfaceContainerLow,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: targetWidth,
                  maxWidth: targetWidth,
                  child: SizedBox(
                    width: targetWidth,
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCollapsed ? 12 : 24,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment:
                                isCollapsed
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.spaceBetween,
                            children: [
                              if (!isCollapsed) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SonoraLogo.icon(32),
                                    const SizedBox(width: 12),
                                    Text(
                                      'SONORA',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              IconButton(
                                icon: Icon(
                                  isCollapsed
                                      ? LucideIcons.menu
                                      : LucideIcons.chevronLeft,
                                ),
                                onPressed: () {
                                  ref
                                      .read(sidebarCollapsedProvider.notifier)
                                      .toggle();
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (var i = 0; i < _icons.length; i++)
                                _buildNavItem(i, context),
                            ],
                          ),
                        ),
                        NavNowPlaying(expanded: !isCollapsed),
                      ],
                    ),
                  ),
                ),
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
                  child: BranchFadeTransition(
                    navigationShell: widget.navigationShell,
                  ),
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

  Widget _buildNavItem(int i, BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isSelected = widget.navigationShell.currentIndex == i;
    final colorScheme = Theme.of(context).colorScheme;
    final label = _getLabel(AppLocalizations.of(context)!, i);

    if (isCollapsed) {
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
              onPressed: () => widget.navigationShell.goBranch(i),
              child: Icon(_icons[i]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Stack(
        children: [
          ScaleButton(
            onTap: () => widget.navigationShell.goBranch(i),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? colorScheme.secondaryContainer.withValues(alpha: 0.4)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _icons[i],
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              width: 3.5,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
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
