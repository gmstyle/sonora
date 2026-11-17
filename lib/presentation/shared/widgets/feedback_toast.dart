import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';

class FeedbackToast {
  static OverlayEntry? _currentEntry;
  static _FeedbackToastWidgetState? _currentState;

  FeedbackToast._();

  /// Whether a sticky (error) toast is currently visible.
  static bool get isStickyVisible => _currentState?._sticky == true;

  /// Moves focus to the active sticky toast so D-pad / Select can close it.
  /// Returns `true` if focus was requested.
  static bool requestFocusIfSticky() {
    final state = _currentState;
    if (state == null || !state._sticky || !state.mounted) return false;
    if (state._closeFocus.canRequestFocus) {
      final current = FocusManager.instance.primaryFocus;
      if (current != null && current != state._closeFocus) {
        state._previousFocus = current;
        state._previousScope = current.enclosingScope;
      }
      state._closeFocus.requestFocus();
      return true;
    }
    return false;
  }

  /// Dismisses the active sticky toast if one is visible. Returns `true` if
  /// a toast was dismissed.
  static bool dismissSticky() {
    final state = _currentState;
    if (state == null || !state._sticky || !state.mounted) return false;
    state._dismiss();
    return true;
  }

  static void show(
    BuildContext context,
    String message, {
    FeedbackKind kind = FeedbackKind.confirm,
  }) {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentState = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _FeedbackToastWidget(
        message: message,
        kind: kind,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) {
            _currentEntry = null;
            _currentState = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentState = null;
  }
}

class _FeedbackToastWidget extends StatefulWidget {
  final String message;
  final FeedbackKind kind;
  final VoidCallback onDismiss;

  const _FeedbackToastWidget({
    required this.message,
    required this.kind,
    required this.onDismiss,
  });

  @override
  State<_FeedbackToastWidget> createState() => _FeedbackToastWidgetState();
}

class _FeedbackToastWidgetState extends State<_FeedbackToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  final FocusNode _closeFocus = FocusNode(debugLabel: 'feedbackToastClose');
  FocusNode? _previousFocus;
  FocusScopeNode? _previousScope;
  bool _closing = false;
  bool _focusRestored = false;

  bool get _sticky => widget.kind == FeedbackKind.error;

  @override
  void initState() {
    super.initState();
    FeedbackToast._currentState = this;
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus != null && currentFocus != _closeFocus) {
      _previousFocus = currentFocus;
      _previousScope = currentFocus.enclosingScope;
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(curve);
    _scale = Tween(begin: 0.85, end: 1.0).animate(curve);

    _controller.forward();

    // Sticky errors must be dismissible with the remote: take focus as soon as
    // the overlay mounts, and listen for Back/Escape globally while visible.
    if (_sticky) {
      HardwareKeyboard.instance.addHandler(_onGlobalKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _closeFocus.canRequestFocus) {
          _closeFocus.requestFocus();
        }
      });
    } else {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _dismiss();
      });
    }
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

  bool _onGlobalKey(KeyEvent event) {
    if (_closing || !_sticky || !mounted || event is! KeyDownEvent) {
      return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _dismiss();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp && !_closeFocus.hasFocus) {
      final beforeFocus = FocusManager.instance.primaryFocus;
      final scrollable = _findVerticalScrollable(beforeFocus?.context);
      final canScrollUp =
          scrollable != null &&
          scrollable.position.hasPixels &&
          scrollable.position.pixels >
              scrollable.position.minScrollExtent + 2.0;
      if (!canScrollUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _closing || !_sticky) return;
          if (FocusManager.instance.primaryFocus == beforeFocus) {
            FeedbackToast.requestFocusIfSticky();
          }
        });
      }
    }
    return false;
  }

  void _restoreFocus({bool markRestored = true}) {
    if (markRestored && _focusRestored) return;
    if (!_sticky) return;
    if (markRestored) _focusRestored = true;
    final hadFocus =
        _closeFocus.hasFocus ||
        FocusManager.instance.primaryFocus == _closeFocus;
    if (!hadFocus) return;

    final prev = _previousFocus;
    if (prev != null && prev.context != null && prev.canRequestFocus) {
      prev.requestFocus();
      return;
    }
    final scope = _previousScope;
    if (scope != null && scope.context != null && scope.canRequestFocus) {
      final candidate = scope.traversalDescendants
          .where((n) => n != _closeFocus && n.canRequestFocus)
          .firstOrNull;
      if (candidate != null) {
        candidate.requestFocus();
        return;
      }
      scope.requestFocus();
      return;
    }
    FocusManager.instance.rootScope.nextFocus();
  }

  Future<void> _dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    if (_sticky) {
      HardwareKeyboard.instance.removeHandler(_onGlobalKey);
      _restoreFocus();
    }
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  KeyEventResult _onToastKey(FocusNode node, KeyEvent event) {
    if (!_sticky || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _restoreFocus(markRestored: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    if (_sticky) {
      HardwareKeyboard.instance.removeHandler(_onGlobalKey);
      if (!_focusRestored) {
        final prev = _previousFocus;
        final scope = _previousScope;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (prev != null && prev.context != null && prev.canRequestFocus) {
            prev.requestFocus();
          } else if (scope != null &&
              scope.context != null &&
              scope.canRequestFocus) {
            scope.requestFocus();
          }
        });
      }
    }
    if (FeedbackToast._currentState == this) {
      FeedbackToast._currentState = null;
    }
    _closeFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final mark = widget.kind == FeedbackKind.error
        ? colorScheme.error
        : colorScheme.primaryContainer;

    return Positioned(
      top: topPadding,
      left: 24,
      right: 24,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Focus(
                  focusNode: _sticky ? _closeFocus : null,
                  autofocus: _sticky,
                  onKeyEvent: _onToastKey,
                  child: Builder(
                    builder: (context) {
                      final focused = _sticky && Focus.of(context).hasFocus;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          _sticky ? 4 : 16,
                          12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: focused
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: focused ? 2 : 1,
                          ),
                          boxShadow: focused
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: mark,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.message,
                                maxLines: _sticky ? 3 : 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (_sticky) ...[
                              const SizedBox(width: 4),
                              // Touch/mouse still use the button; remote
                              // activation is owned by the parent Focus so
                              // D-pad cannot strand on a nested IconButton.
                              ExcludeFocus(
                                child: IconButton(
                                  onPressed: _dismiss,
                                  tooltip: l10n?.close ?? 'Close',
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  icon: Icon(
                                    LucideIcons.x,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
