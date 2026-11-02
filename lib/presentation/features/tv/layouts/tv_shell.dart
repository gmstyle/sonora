import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/playlist_import_job_provider.dart';
import '../../../shared/widgets/action_feedback_listener.dart';
import '../../../shared/widgets/branch_fade_transition.dart';
import '../../../shared/widgets/dock_status_banners.dart';
import '../../../shared/widgets/player_error_listener.dart';
import '../../../shared/widgets/playlist_import_job_host.dart';
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

/// Android TV chrome: collapsible left nav rail + content + mini player dock.
///
/// Rail is ~[TvMetrics.sidebarExpandedWidth] while a nav item holds focus and
/// collapses to ~[TvMetrics.sidebarCollapsedWidth] when content is focused.
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

  /// Owns the rail so [hasFocus] is true while any destination is focused.
  late final FocusScopeNode _sidebarScope;

  /// True while any rail destination (or settings) holds focus.
  bool _navFocused = true;

  @override
  void initState() {
    super.initState();
    _navNodes = List<FocusNode>.generate(
      _tvNavIcons.length + 1,
      (i) => FocusNode(debugLabel: 'tv-nav-$i'),
      growable: false,
    );
    _sidebarScope = FocusScopeNode(debugLabel: 'tv-sidebar-scope');
    _sidebarScope.addListener(_onSidebarFocusChange);
    FocusManager.instance.addListener(_onFocusManagerChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusManagerChange);
    _sidebarScope.removeListener(_onSidebarFocusChange);
    _sidebarScope.dispose();
    for (final node in _navNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onSidebarFocusChange() => _syncNavFocused(_sidebarScope.hasFocus);

  void _onFocusManagerChange() => _syncNavFocused(_sidebarScope.hasFocus);

  void _syncNavFocused(bool focused) {
    if (focused != _navFocused) {
      setState(() => _navFocused = focused);
    }
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
    final bannersVisible = ref.watch(dockBannersVisibleProvider);
    final labels = [l10n.home, l10n.search, l10n.library, l10n.downloads];
    final currentIndex = widget.navigationShell.currentIndex;
    final expanded = _navFocused;
    final railWidth =
        expanded
            ? TvMetrics.sidebarExpandedWidth
            : TvMetrics.sidebarCollapsedWidth;
    final playerInset = isPlayerActive ? TvMetrics.miniPlayerHeight : 0.0;
    final contentBottom =
        isPlayerActive
            ? playerInset
            : (bannersVisible ? TvMetrics.dockBannerInset : 0.0);

    return TvShellFocus(
      focusSidebar: _focusSidebar,
      child: Scaffold(
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              width: railWidth,
              child: Material(
                color: colorScheme.surfaceContainerLow,
                child: FocusScope(
                  node: _sidebarScope,
                  child: DpadRegion(
                    memoryKey: 'tv/sidebar',
                    debugLabel: 'tv/sidebar',
                    verticalEdge: DpadEdgeBehavior.stop,
                    horizontalEdge: DpadEdgeBehavior.leave,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        expanded ? 12 : 8,
                        28,
                        expanded ? 12 : 8,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              expanded ? 12 : 0,
                              0,
                              expanded ? 12 : 0,
                              20,
                            ),
                            child:
                                expanded
                                    ? Row(
                                      children: [
                                        const SonoraLogo.icon(36),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            'SONORA',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    : const Center(child: SonoraLogo.icon(32)),
                          ),
                          for (var i = 0; i < _tvNavIcons.length; i++)
                            _TvNavItem(
                              focusNode: _navNodes[i],
                              icon: _tvNavIcons[i],
                              label: labels[i],
                              selected: currentIndex == i,
                              autofocus: i == 0,
                              entry: i == currentIndex,
                              expanded: expanded,
                              onSelect: () {
                                widget.navigationShell.goBranch(i);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
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
                                GoRouterState.of(context).uri.path ==
                                '/settings',
                            expanded: expanded,
                            onSelect: () => context.push('/settings'),
                          ),
                        ],
                      ),
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
                    padding: EdgeInsets.only(bottom: contentBottom),
                    child: BranchFadeTransition(
                      navigationShell: widget.navigationShell,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: playerInset,
                    child: const DockStatusBanners(),
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
                  const PlaylistImportJobHost(),
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
  final bool expanded;
  final VoidCallback onSelect;

  const _TvNavItem({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.expanded,
    this.autofocus = false,
    this.entry = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
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
          padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
          alignment: expanded ? Alignment.centerLeft : Alignment.center,
          child:
              expanded
                  ? Row(
                    children: [
                      Icon(icon, size: 26, color: iconColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                selected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Icon(icon, size: 26, color: iconColor),
        ),
      ),
    );
  }
}
