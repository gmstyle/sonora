import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Animated play/pause icon that cross-fades between states.
///
/// When [isLoading] is true a [CircularProgressIndicator] is shown instead,
/// used while the player is restoring state from disk.
///
/// Previously a `StatefulWidget` with a `SingleTickerProviderStateMixin` and
/// an `AnimationController`.  The controller was created and animated in
/// `didUpdateWidget` but never referenced in `build`, which used
/// `AnimatedSwitcher` exclusively.  Simplified to `StatelessWidget`.
class AnimatedPlayPauseIcon extends StatelessWidget {
  final bool isPlaying;

  /// When true shows a [CircularProgressIndicator] instead of the icon.
  final bool isLoading;

  final Color color;
  final double size;

  const AnimatedPlayPauseIcon({
    super.key,
    required this.isPlaying,
    this.isLoading = false,
    required this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        isPlaying ? LucideIcons.pause : LucideIcons.play,
        key: ValueKey(isPlaying),
        color: color,
        size: size,
      ),
    );
  }
}
