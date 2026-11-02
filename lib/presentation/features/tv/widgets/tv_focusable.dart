import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/android_tv_provider.dart';
import '../../../providers/settings_provider.dart';
import '../tv_metrics.dart';

/// Sonora-styled [DpadFocusable] with primary border + slight scale on focus.
///
/// Scale respects [Settings.reduceEffects] (border remains for focus clarity).
class TvFocusable extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
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
        if (!reduceEffects) DpadScaleEffect(scale: TvMetrics.focusScale),
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

/// Pass-through on phone/tablet; wraps with [TvFocusable] on Android TV.
///
/// Use for shared catalog tiles/cards so Select activates and long-select
/// opens the context menu without forking every layout for TV.
class MaybeTvFocusable extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final bool autofocus;
  final bool enabled;
  final String? debugLabel;

  const MaybeTvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onLongSelect,
    this.autofocus = false,
    this.enabled = true,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAndroidTvProvider)) return child;
    return TvFocusable(
      autofocus: autofocus,
      enabled: enabled,
      onSelect: onSelect,
      onLongSelect: onLongSelect,
      debugLabel: debugLabel,
      child: child,
    );
  }
}
