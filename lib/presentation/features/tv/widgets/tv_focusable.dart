import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tv_metrics.dart';

/// Focus wrapper for 10-foot TV: scale + Pulse outline on focus.
///
/// Optional [onLeftAtEdge] fires when Left is pressed and this node has no
/// westward sibling (used to hand focus to the sidebar).
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final VoidCallback? onLeftAtEdge;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onLongSelect,
    this.onLeftAtEdge,
    this.autofocus = false,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  final FocusNode _node = FocusNode(debugLabel: 'TvFocusable');
  bool _focused = false;
  DateTime? _keyDownAt;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isSelect =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isSelect) {
      if (event is KeyDownEvent) {
        _keyDownAt = DateTime.now();
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        final down = _keyDownAt;
        _keyDownAt = null;
        if (down != null &&
            DateTime.now().difference(down) >=
                const Duration(milliseconds: 500)) {
          widget.onLongSelect?.call();
        } else {
          widget.onSelect?.call();
        }
        return KeyEventResult.handled;
      }
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        widget.onLeftAtEdge != null) {
      widget.onLeftAtEdge!();
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
