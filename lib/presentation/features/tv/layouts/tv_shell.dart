import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/action_feedback_listener.dart';
import '../../../shared/widgets/branch_fade_transition.dart';
import '../../../shared/widgets/dock_status_banners.dart';
import '../../../shared/widgets/player_error_listener.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_dock.dart';

final _destinations = [
  (LucideIcons.home, (AppLocalizations l) => l.home),
  (LucideIcons.search, (AppLocalizations l) => l.search),
  (LucideIcons.library, (AppLocalizations l) => l.library),
  (LucideIcons.download, (AppLocalizations l) => l.downloads),
];

/// Android TV chrome: JetFit-style collapsible nav drawer + branch content.
///
/// Collapsed = icon rail ([TvMetrics.railCollapsedWidth]). Focus inside the
/// drawer expands to [TvMetrics.railExpandedWidth] with labels. Content uses
/// dedicated TV screens via root-screen dispatch — not touch layouts.
///
/// Focus scopes: sidebar ↔ content ↔ dock. Down past the last content
/// focusable (or past Settings) moves to the mini-player strip.
class TvShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const TvShell({super.key, required this.navigationShell});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  final FocusScopeNode _sidebarScope = FocusScopeNode(debugLabel: 'tvSidebar');
  final FocusScopeNode _contentScope = FocusScopeNode(debugLabel: 'tvContent');
  final FocusScopeNode _dockScope = FocusScopeNode(debugLabel: 'tvDock');
  bool _drawerExpanded = false;

  @override
  void dispose() {
    _sidebarScope.dispose();
    _contentScope.dispose();
    _dockScope.dispose();
    super.dispose();
  }

  void _setExpanded(bool value) {
    if (_drawerExpanded == value) return;
    setState(() => _drawerExpanded = value);
  }

  bool get _dockAvailable => ref.read(playerStateProvider).currentSong != null;

  void _focusDock() {
    if (!_dockAvailable) return;
    _dockScope.requestFocus();
  }

  void _focusContent() => _contentScope.requestFocus();

  void _focusSidebar() => _sidebarScope.requestFocus();

  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_contentScope.focusInDirection(TraversalDirection.down)) {
        return KeyEventResult.handled;
      }
      if (_dockAvailable) {
        _focusDock();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // Let item-level onLeftAtEdge run first (ignored here). If nothing
      // handled Left inside content, fall through to default traversal.
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onDockKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_dockScope.focusInDirection(TraversalDirection.up)) {
        return KeyEventResult.handled;
      }
      _focusContent();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_dockScope.focusInDirection(TraversalDirection.left)) {
        return KeyEventResult.handled;
      }
      _focusSidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onSidebarKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_sidebarScope.focusInDirection(TraversalDirection.down)) {
        return KeyEventResult.handled;
      }
      if (_dockAvailable) {
        _focusDock();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_sidebarScope.focusInDirection(TraversalDirection.right)) {
        return KeyEventResult.handled;
      }
      _focusContent();
      _setExpanded(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final expanded = _drawerExpanded;
    // Rebuild when queue presence changes so dock focus targets stay valid.
    ref.watch(playerStateProvider.select((s) => s.currentSong != null));

    return TvShellFocus(
      focusSidebar: _focusSidebar,
      focusDock: _focusDock,
      focusContent: _focusContent,
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      SizedBox(width: TvMetrics.railCollapsedWidth),
                      Expanded(
                        child: FocusScope(
                          node: _contentScope,
                          onKeyEvent: _onContentKey,
                          child: Stack(
                            children: [
                              BranchFadeTransition(
                                navigationShell: navigationShell,
                              ),
                              const PlayerErrorListener(),
                              const ActionFeedbackListener(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (expanded)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          _sidebarScope.unfocus();
                          _focusContent();
                        },
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  FocusScope(
                    node: _sidebarScope,
                    onFocusChange: _setExpanded,
                    onKeyEvent: _onSidebarKey,
                    child: AnimatedContainer(
                      duration: TvMetrics.drawerAnimDuration,
                      curve: Curves.easeOutCubic,
                      width: expanded
                          ? TvMetrics.railExpandedWidth
                          : TvMetrics.railCollapsedWidth,
                      clipBehavior: Clip.hardEdge,
                      color: colorScheme.surfaceContainerLow,
                      child: LayoutBuilder(
                        builder: (context, railConstraints) {
                          // Labels follow actual width, not the expand flag —
                          // otherwise the Row overflows mid-animation (~3px+).
                          final showLabels =
                              railConstraints.maxWidth >=
                              TvMetrics.railExpandedWidth - 8;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  showLabels ? 20 : 0,
                                  28,
                                  showLabels ? 12 : 0,
                                  20,
                                ),
                                child: showLabels
                                    ? Row(
                                        children: [
                                          const SonoraLogo.icon(36),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Sonora',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Center(child: SonoraLogo.icon(36)),
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  children: [
                                    for (
                                      var i = 0;
                                      i < _destinations.length;
                                      i++
                                    )
                                      _TvNavItem(
                                        icon: _destinations[i].$1,
                                        label: _destinations[i].$2(l10n),
                                        selected:
                                            navigationShell.currentIndex == i,
                                        expanded: showLabels,
                                        autofocus: i == 0,
                                        onSelect: () {
                                          navigationShell.goBranch(i);
                                          _setExpanded(false);
                                          _focusContent();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              _TvNavItem(
                                icon: LucideIcons.settings,
                                label: l10n.settingsLabel,
                                selected:
                                    GoRouterState.of(context).uri.path ==
                                    '/settings',
                                expanded: showLabels,
                                onSelect: () {
                                  context.push('/settings');
                                  _setExpanded(false);
                                },
                                onDown: _dockAvailable ? _focusDock : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const DockStatusBanners(),
            FocusScope(
              node: _dockScope,
              onKeyEvent: _onDockKey,
              child: const TvDock(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback? onDown;

  const _TvNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    this.autofocus = false,
    this.onDown,
  });

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = widget.selected || _focused
        ? colorScheme.primary
        : colorScheme.onSurface;
    final bg = widget.selected
        ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
        : _focused
        ? colorScheme.surfaceContainerHighest
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (v) {
          if (_focused != v) setState(() => _focused = v);
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final isSelect =
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space;
          if (isSelect) {
            widget.onSelect();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              widget.onDown != null) {
            widget.onDown!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onSelect,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  SizedBox(
                    width: TvMetrics.railCollapsedWidth - 16,
                    child: Icon(
                      widget.icon,
                      size: TvMetrics.railIconSize,
                      color: fg,
                    ),
                  ),
                  if (widget.expanded)
                    Expanded(
                      child: Text(
                        widget.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: fg,
                              fontWeight: widget.selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
