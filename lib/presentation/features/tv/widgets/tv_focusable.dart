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
  DateTime? _keyDownAt;
  bool _longFired = false;

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
    if (_longFired) return;
    _longFired = true;
    widget.onLongSelect?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_isSelect(event.logicalKey)) {
      if (event is KeyDownEvent) {
        _keyDownAt = DateTime.now();
        _longFired = false;
        return KeyEventResult.handled;
      }
      if (event is KeyRepeatEvent) {
        final down = _keyDownAt;
        if (down != null &&
            !_longFired &&
            widget.onLongSelect != null &&
            DateTime.now().difference(down) >= _longPress) {
          _fireLong();
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        final down = _keyDownAt;
        _keyDownAt = null;
        if (_longFired) {
          _longFired = false;
          return KeyEventResult.handled;
        }
        if (down != null &&
            widget.onLongSelect != null &&
            DateTime.now().difference(down) >= _longPress) {
          _fireLong();
          _longFired = false;
          return KeyEventResult.handled;
        }
        _longFired = false;
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
        if (_focused != hasFocus) setState(() => _focused = hasFocus);
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
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _focused ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
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
