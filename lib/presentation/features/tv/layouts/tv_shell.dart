import 'dart:async';
import 'dart:math' as math;

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
import '../../../shared/widgets/feedback_toast.dart';
import '../../../shared/widgets/player_error_listener.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/youtube_account_button.dart';
import '../screens/tv_now_playing_screen.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_now_playing_pill.dart';

final _destinations = [
  (LucideIcons.home, (AppLocalizations l) => l.home),
  (LucideIcons.search, (AppLocalizations l) => l.search),
  (LucideIcons.library, (AppLocalizations l) => l.library),
  (LucideIcons.download, (AppLocalizations l) => l.downloads),
];

/// Android TV chrome: Material TV left-navigation overlay + browse content.
///
/// Collapsed = icon rail ([TvMetrics.railCollapsedWidth]). Focus expands to
/// [TvMetrics.railExpandedWidth] as an overlay (content width stays fixed).
/// Screens are dedicated TV widgets — not touch layouts.
///
/// Focus scopes: sidebar ↔ content. A top-right pill and sidebar "Now Playing"
/// entry open [TvNowPlayingScreen] without reserving a bottom bar.
class TvShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const TvShell({super.key, required this.navigationShell});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  final FocusScopeNode _sidebarScope = FocusScopeNode(debugLabel: 'tvSidebar');
  final FocusScopeNode _contentScope = FocusScopeNode(debugLabel: 'tvContent');
  late final List<FocusNode> _navNodes;
  final FocusNode _nowPlayingNavNode = FocusNode(debugLabel: 'tvNavNowPlaying');
  final FocusNode _pillFocusNode = FocusNode(debugLabel: 'tvNowPlayingPill');
  final FocusNode _accountNavNode = FocusNode(debugLabel: 'tvNavAccount');
  final FocusNode _settingsNavNode = FocusNode(debugLabel: 'tvNavSettings');
  bool _drawerExpanded = false;
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _navNodes = List.generate(
      _destinations.length,
      (i) => FocusNode(debugLabel: 'tvNav$i'),
    );
  }

  @override
  void dispose() {
    _sidebarScope.dispose();
    _contentScope.dispose();
    for (final node in _navNodes) {
      node.dispose();
    }
    _nowPlayingNavNode.dispose();
    _pillFocusNode.dispose();
    _accountNavNode.dispose();
    _settingsNavNode.dispose();
    super.dispose();
  }

  void _setExpanded(bool value) {
    if (_drawerExpanded == value) return;
    setState(() => _drawerExpanded = value);
  }

  bool _isOffstage(BuildContext? ctx) {
    if (ctx == null) return true;
    var offstage = false;
    ctx.visitAncestorElements((element) {
      if (element.widget is Offstage && (element.widget as Offstage).offstage) {
        offstage = true;
        return false;
      }
      return true;
    });
    return offstage;
  }

  void _focusContent({bool resetToFirst = false}) {
    _setExpanded(false);
    void applyFocus() {
      if (!mounted) return;
      final saved = _contentScope.focusedChild;
      if (!resetToFirst &&
          saved != null &&
          saved.canRequestFocus &&
          !_isOffstage(saved.context)) {
        saved.requestFocus();
        return;
      }
      final firstVisible = _contentScope.traversalDescendants
          .where((n) => n != _pillFocusNode && !_isOffstage(n.context))
          .firstOrNull;
      if (firstVisible != null) {
        firstVisible.requestFocus();
      } else {
        _contentScope.requestFocus();
      }
    }

    if (resetToFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) => applyFocus());
      WidgetsBinding.instance.scheduleFrame();
    } else {
      applyFocus();
    }
  }

  void _focusSidebar() {
    _setExpanded(true);
    final idx = widget.navigationShell.currentIndex;
    if (idx >= 0 && idx < _navNodes.length) {
      _navNodes[idx].requestFocus();
    } else {
      _sidebarScope.requestFocus();
    }
  }

  bool _focusInScope(FocusScopeNode scope, TraversalDirection direction) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == scope) return false;
    return primary.focusInDirection(direction);
  }

  ScrollableState? _findVerticalScrollable(BuildContext? ctx) {
    if (ctx == null) return null;
    ScrollableState? result;
    ctx.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        if (axisDirectionToAxis(scrollable.axisDirection) == Axis.vertical) {
          result = scrollable;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusInScope(_contentScope, TraversalDirection.down)) {
        return KeyEventResult.handled;
      }
      final primaryFocus = FocusManager.instance.primaryFocus;
      // Leaving the top-right pill downward: return to the first visible item.
      if (primaryFocus == _pillFocusNode) {
        final firstContent = _contentScope.traversalDescendants
            .where((n) => n != _pillFocusNode && !_isOffstage(n.context))
            .firstOrNull;
        if (firstContent != null) {
          firstContent.requestFocus();
          return KeyEventResult.handled;
        }
      }
      // If directional focus down failed, attempt to scroll the nearest
      // vertical scrollable down so lazy items can mount and receive focus.
      final scrollable = _findVerticalScrollable(primaryFocus?.context);
      if (scrollable != null &&
          scrollable.position.hasPixels &&
          scrollable.position.pixels <
              scrollable.position.maxScrollExtent - 2.0) {
        final target = math.min(
          scrollable.position.pixels + 200.0,
          scrollable.position.maxScrollExtent,
        );
        scrollable.position
            .animateTo(
              target,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
              if (mounted) {
                _focusInScope(_contentScope, TraversalDirection.down);
              }
            });
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusInScope(_contentScope, TraversalDirection.up)) {
        return KeyEventResult.handled;
      }
      final primaryFocus = FocusManager.instance.primaryFocus;
      final scrollable = _findVerticalScrollable(primaryFocus?.context);
      if (scrollable != null &&
          scrollable.position.hasPixels &&
          scrollable.position.pixels >
              scrollable.position.minScrollExtent + 2.0) {
        final target = math.max(
          scrollable.position.pixels - 200.0,
          scrollable.position.minScrollExtent,
        );
        scrollable.position
            .animateTo(
              target,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
              if (mounted) {
                _focusInScope(_contentScope, TraversalDirection.up);
              }
            });
        return KeyEventResult.handled;
      }
      // At the top of the screen: first reach any sticky error toast above,
      // otherwise move focus to the top-right Now Playing pill.
      if (FeedbackToast.requestFocusIfSticky()) {
        return KeyEventResult.handled;
      }
      if (primaryFocus != _pillFocusNode &&
          _pillFocusNode.context != null &&
          _pillFocusNode.canRequestFocus) {
        _pillFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_focusInScope(_contentScope, TraversalDirection.left)) {
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
      _focusInScope(_sidebarScope, TraversalDirection.down);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusInScope(_sidebarScope, TraversalDirection.up);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          _focusInScope(_sidebarScope, TraversalDirection.right)) {
        return KeyEventResult.handled;
      }
      _focusContent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _confirmAndExit() async {
    if (_exitDialogOpen || !mounted) return;
    _exitDialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    final hasActiveSong = ref.read(playerStateProvider).currentSong != null;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            backgroundColor: TvColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: TvColors.border),
            ),
            title: Text(
              l10n.tvExitAppTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: TvColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: hasActiveSong
                ? Text(
                    l10n.tvExitAppMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: TvColors.textSecondary,
                    ),
                  )
                : null,
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.tvExitAppAction),
              ),
            ],
          );
        },
      );
      if (confirmed == true && mounted) {
        await ref.read(playerStateProvider.notifier).pause();
        await SystemNavigator.pop();
      }
    } finally {
      _exitDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final expanded = _drawerExpanded;
    final currentSong = ref.watch(
      playerStateProvider.select((s) => s.currentSong),
    );
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (FeedbackToast.dismissSticky()) return;
        if (expanded) {
          _focusContent();
          return;
        }
        unawaited(_confirmAndExit());
      },
      child: TvShellFocus(
        focusSidebar: _focusSidebar,
        focusContent: _focusContent,
        child: Scaffold(
          backgroundColor: TvColors.bg,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Subtle ambient radial aura from Canvas (`ambient-backdrop`)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.4, -0.4),
                              radius: 1.15,
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.14),
                                const Color(0xFF1E1B4B).withValues(alpha: 0.35),
                                TvColors.bg,
                              ],
                              stops: const [0.0, 0.48, 0.95],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(width: TvMetrics.railCollapsedWidth),
                        Expanded(
                          child: FocusScope(
                            node: _contentScope,
                            autofocus: true,
                            onKeyEvent: _onContentKey,
                            child: Stack(
                              children: [
                                BranchFadeTransition(
                                  navigationShell: navigationShell,
                                ),
                                Positioned(
                                  top: 14,
                                  right: TvMetrics.contentPadding,
                                  child: TvNowPlayingPill(
                                    focusNode: _pillFocusNode,
                                    onLeftAtEdge: _focusSidebar,
                                  ),
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
                            color: Colors.black.withValues(alpha: 0.55),
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
                        decoration: BoxDecoration(
                          color: TvColors.railBg,
                          border: const Border(
                            right: BorderSide(color: TvColors.border),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(8, 0),
                            ),
                          ],
                        ),
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Center(
                                          child: SonoraLogo.icon(36),
                                        ),
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
                                          focusNode: _navNodes[i],
                                          icon: _destinations[i].$1,
                                          label: _destinations[i].$2(l10n),
                                          selected:
                                              navigationShell.currentIndex == i,
                                          expanded: showLabels,
                                          onSelect: () {
                                            final changed =
                                                navigationShell.currentIndex !=
                                                i;
                                            navigationShell.goBranch(i);
                                            _focusContent(
                                              resetToFirst: changed,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                if (currentSong != null)
                                  _TvSidebarNowPlayingItem(
                                    focusNode: _nowPlayingNavNode,
                                    title: currentSong.title,
                                    subtitle: l10n.queueNowPlayingChip,
                                    artUrl: currentSong.artUri?.toString(),
                                    isPlaying: isPlaying,
                                    expanded: showLabels,
                                    onSelect: () {
                                      _setExpanded(false);
                                      openTvNowPlaying(context);
                                    },
                                  ),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final accountLabel =
                                        resolveYoutubeAccountLabel(
                                          context,
                                          ref,
                                        );
                                    return _TvNavItem(
                                      key: const Key('tv-account-button'),
                                      focusNode: _accountNavNode,
                                      icon: LucideIcons.user,
                                      leadingBuilder: (fg) =>
                                          YoutubeAccountAvatar(
                                            size: TvMetrics.railIconSize,
                                            iconColor: fg,
                                          ),
                                      label: accountLabel,
                                      selected: false,
                                      expanded: showLabels,
                                      onSelect: () {
                                        _setExpanded(false);
                                        unawaited(
                                          handleYoutubeAccountTap(context, ref),
                                        );
                                      },
                                    );
                                  },
                                ),
                                _TvNavItem(
                                  focusNode: _settingsNavNode,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _TvNavItem extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final Widget Function(Color color)? leadingBuilder;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onSelect;

  const _TvNavItem({
    super.key,
    required this.focusNode,
    required this.icon,
    this.leadingBuilder,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onSelect,
  });

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = widget.selected || _focused;
    final fg = _focused
        ? TvColors.textPrimary
        : widget.selected
        ? colorScheme.primary
        : TvColors.textSecondary;
    final bg = _focused
        ? colorScheme.primary.withValues(alpha: 0.22)
        : widget.selected
        ? colorScheme.primary.withValues(alpha: 0.14)
        : Colors.transparent;
    final borderColor = _focused
        ? colorScheme.primary
        : widget.selected
        ? colorScheme.primary.withValues(alpha: 0.35)
        : Colors.transparent;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? 12 : 10,
        vertical: 4,
      ),
      child: Focus(
        focusNode: widget.focusNode,
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
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: TvMetrics.drawerAnimDuration,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 14 : 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: _focused ? 2 : 1),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: widget.expanded
                ? Row(
                    children: [
                      widget.leadingBuilder?.call(fg) ??
                          Icon(
                            widget.icon,
                            size: TvMetrics.railIconSize,
                            color: fg,
                          ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: fg,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child:
                        widget.leadingBuilder?.call(fg) ??
                        Icon(
                          widget.icon,
                          size: TvMetrics.railIconSize,
                          color: fg,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TvSidebarNowPlayingItem extends StatefulWidget {
  final FocusNode focusNode;
  final String title;
  final String subtitle;
  final String? artUrl;
  final bool isPlaying;
  final bool expanded;
  final VoidCallback onSelect;

  const _TvSidebarNowPlayingItem({
    required this.focusNode,
    required this.title,
    required this.subtitle,
    required this.artUrl,
    required this.isPlaying,
    required this.expanded,
    required this.onSelect,
  });

  @override
  State<_TvSidebarNowPlayingItem> createState() =>
      _TvSidebarNowPlayingItemState();
}

class _TvSidebarNowPlayingItemState extends State<_TvSidebarNowPlayingItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = _focused
        ? colorScheme.primary.withValues(alpha: 0.22)
        : colorScheme.primary.withValues(alpha: 0.10);
    final borderColor = _focused
        ? colorScheme.primary
        : colorScheme.primary.withValues(alpha: 0.28);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? 12 : 10,
        vertical: 4,
      ),
      child: Focus(
        focusNode: widget.focusNode,
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
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: TvMetrics.drawerAnimDuration,
            height: 52,
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 10 : 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: _focused ? 2 : 1),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: widget.expanded
                ? Row(
                    children: [
                      ThumbnailWidget(
                        imageUrl: widget.artUrl,
                        size: 32,
                        shape: ThumbnailShape.rounded,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subtitle.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: TvColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isPlaying) ...[
                        const SizedBox(width: 6),
                        TvMiniEqBars(color: colorScheme.primary),
                      ],
                    ],
                  )
                : Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ThumbnailWidget(
                          imageUrl: widget.artUrl,
                          size: 32,
                          shape: ThumbnailShape.rounded,
                          borderRadius: 8,
                        ),
                        if (widget.isPlaying)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary,
                                border: Border.all(
                                  color: TvColors.railBg,
                                  width: 1.5,
                                ),
                              ),
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
