import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable frosted-glass background widget for AppBars and SliverAppBars.
/// It uses a native hardware-accelerated [BackdropFilter] for blur,
/// combined with a semi-transparent color tint using the theme's surface color.
class GlassAppBarBackground extends StatelessWidget {
  final double opacity;

  const GlassAppBarBackground({super.key, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15.0 * opacity,
          sigmaY: 15.0 * opacity,
        ),
        child: Container(color: surfaceColor.withValues(alpha: 0.65 * opacity)),
      ),
    );
  }
}
