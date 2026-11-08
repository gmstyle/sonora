import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// A reusable frosted-glass background widget for AppBars and SliverAppBars.
/// It uses a native hardware-accelerated [BackdropFilter] for blur,
/// combined with a semi-transparent color tint using the theme's surface color.
class GlassAppBarBackground extends StatelessWidget {
  final double opacity;

  /// Tint over the blur. Defaults to [ColorScheme.surface].
  final Color? color;

  /// Skip the backdrop blur when motion and effects are reduced.
  final bool blur;

  const GlassAppBarBackground({
    super.key,
    this.opacity = 1.0,
    this.color,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.0) return const SizedBox.shrink();

    final surfaceColor = color ?? Theme.of(context).colorScheme.surface;
    final tint = Container(
      color: surfaceColor.withValues(alpha: 0.65 * opacity),
    );
    if (!blur) return tint;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15.0 * opacity,
          sigmaY: 15.0 * opacity,
        ),
        child: tint,
      ),
    );
  }
}
