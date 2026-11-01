import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';

import '../tv_metrics.dart';

/// Sonora-styled [DpadFocusable] with primary border + slight scale on focus.
class TvFocusable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final ValueChanged<bool>? onFocusChange;
  final DpadDirectionCallback? onDirection;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool entry;
  final bool excludeChildFocus;
  final String? debugLabel;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onLongSelect,
    this.onFocusChange,
    this.onDirection,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.entry = false,
    this.excludeChildFocus = true,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DpadFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      entry: entry,
      onSelect: onSelect,
      onLongSelect: onLongSelect,
      onFocusChange: onFocusChange,
      onDirection: onDirection,
      excludeChildFocus: excludeChildFocus,
      debugLabel: debugLabel,
      effects: [
        DpadScaleEffect(scale: TvMetrics.focusScale),
        DpadBorderEffect(
          color: colorScheme.primary,
          width: 3,
          borderRadius: BorderRadius.circular(16),
        ),
      ],
      child: child,
    );
  }
}
