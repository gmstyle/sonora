import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tv_metrics.dart';

/// Focus wrapper for 10-foot TV: scale + Pulse outline on focus.
///
/// Optional [onLeftAtEdge] / [onDownAtEdge] hand focus to sidebar / content
/// below when directional traversal would otherwise leave the widget.
///
/// Long-press Select (≥400ms, or first KeyRepeat after that) fires
/// [onLongSelect] — used for TV context menus.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final VoidCallback? onLeftAtEdge;
  final VoidCallback? onDownAtEdge;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final FocusNode? focusNode;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onLongSelect,
    this.onLeftAtEdge,
    this.onDownAtEdge,
    this.onFocusChange,
    this.autofocus = false,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.focusNode,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _ownedNode;
  bool _focused = false;
  bool _isPressed = false;
  bool _longFired = false;
  Timer? _longPressTimer;

  static const _longPress = Duration(milliseconds: 400);

  FocusNode get _node => widget.focusNode ?? _ownedNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedNode = FocusNode(debugLabel: 'TvFocusable');
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _ownedNode?.dispose();
    super.dispose();
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.mediaPlayPause;

  void _fireLong() {
    if (!mounted || _longFired || !_isPressed) return;
    _longFired = true;
    widget.onLongSelect?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_isSelect(event.logicalKey)) {
      if (event is KeyDownEvent) {
        _isPressed = true;
        _longFired = false;
        _longPressTimer?.cancel();
        if (widget.onLongSelect != null) {
          _longPressTimer = Timer(_longPress, _fireLong);
        }
        return KeyEventResult.handled;
      }
      if (event is KeyRepeatEvent) {
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (!_isPressed) {
          return KeyEventResult.ignored;
        }
        _isPressed = false;
        if (_longFired) {
          _longFired = false;
          return KeyEventResult.handled;
        }
        widget.onSelect?.call();
        return KeyEventResult.handled;
      }
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        widget.onLeftAtEdge != null) {
      widget.onLeftAtEdge!();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.onDownAtEdge != null) {
      widget.onDownAtEdge!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(TvMetrics.cardRadius);

    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _longPressTimer?.cancel();
          _isPressed = false;
          _longFired = false;
        }
        if (_focused != hasFocus) setState(() => _focused = hasFocus);
        if (hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_node.hasFocus) return;
            final scrollable = Scrollable.maybeOf(context);
            if (scrollable != null &&
                axisDirectionToAxis(scrollable.axisDirection) ==
                    Axis.horizontal) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: TvMetrics.drawerAnimDuration,
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
        widget.onFocusChange?.call(hasFocus);
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        onLongPress: widget.onLongSelect,
        child: AnimatedScale(
          scale: _focused ? TvMetrics.focusScale : 1.0,
          duration: TvMetrics.drawerAnimDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: TvMetrics.drawerAnimDuration,
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            // strokeAlignOutside keeps the 3px ring from eating layout
            // space (poster cards were overflowing by 2px from the inset).
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _focused ? colorScheme.primary : Colors.transparent,
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.55),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
