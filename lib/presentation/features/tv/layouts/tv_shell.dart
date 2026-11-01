import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/action_feedback_listener.dart';
import '../../../shared/widgets/branch_fade_transition.dart';
import '../../../shared/widgets/player_error_listener.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_mini_player.dart';

final _tvNavIcons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
];

/// Android TV chrome: left nav rail + content + mini player dock.
///
/// Branch navigators each own a [FocusScope], so D-pad `leave` from content
/// cannot reach the rail. Content shelves call [TvShellFocus.focusSidebar]
/// on Left-edge instead (see [TvShelf]).
class TvShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const TvShell({super.key, required this.navigationShell});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  /// One node per primary destination + settings — used to pull focus out of
  /// branch Navigator scopes.
  late final List<FocusNode> _navNodes;

  @override
  void initState() {
    super.initState();
    _navNodes = List<FocusNode>.generate(
      _tvNavIcons.length + 1,
      (i) => FocusNode(debugLabel: 'tv-nav-$i'),
      growable: false,
    );
  }

  @override
  void dispose() {
    for (final node in _navNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusSidebar() {
    final index = widget.navigationShell.currentIndex.clamp(
      0,
      _tvNavIcons.length - 1,
    );
    final node = _navNodes[index];
    if (node.canRequestFocus) {
      node.requestFocus();
    } else {
      _navNodes.first.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;
    final labels = [l10n.home, l10n.search, l10n.library, l10n.downloads];
    final currentIndex = widget.navigationShell.currentIndex;

    return TvShellFocus(
      focusSidebar: _focusSidebar,
      child: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: TvMetrics.sidebarWidth,
              child: Material(
                color: colorScheme.surfaceContainerLow,
                child: DpadRegion(
                  memoryKey: 'tv/sidebar',
                  debugLabel: 'tv/sidebar',
                  verticalEdge: DpadEdgeBehavior.stop,
                  horizontalEdge: DpadEdgeBehavior.leave,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 28, 12, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          child: Row(
                            children: [
                              const SonoraLogo.icon(36),
                              const SizedBox(width: 12),
                              Text(
                                'SONORA',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var i = 0; i < _tvNavIcons.length; i++)
                          _TvNavItem(
                            focusNode: _navNodes[i],
                            icon: _tvNavIcons[i],
                            label: labels[i],
                            selected: currentIndex == i,
                            autofocus: i == 0,
                            entry: i == currentIndex,
                            onSelect: () {
                              widget.navigationShell.goBranch(i);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted) return;
                                Dpad.maybeOf(context)?.moveRight();
                              });
                            },
                          ),
                        _TvNavItem(
                          focusNode: _navNodes.last,
                          icon: LucideIcons.settings,
                          label: l10n.settingsLabel,
                          selected:
                              GoRouterState.of(context).uri.path == '/settings',
                          onSelect: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: isPlayerActive ? TvMetrics.miniPlayerHeight : 0,
                    ),
                    child: BranchFadeTransition(
                      navigationShell: widget.navigationShell,
                    ),
                  ),
                  if (isPlayerActive)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: TvMiniPlayer(),
                    ),
                  const PlayerErrorListener(),
                  const ActionFeedbackListener(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvNavItem extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool selected;
  final bool autofocus;
  final bool entry;
  final VoidCallback onSelect;

  const _TvNavItem({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.autofocus = false,
    this.entry = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        entry: entry,
        debugLabel: 'nav:$label',
        onSelect: onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: TvMetrics.navItemHeight,
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 26,
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
