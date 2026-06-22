import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AnimatedPlayPauseIcon extends StatefulWidget {
  final bool isPlaying;

  /// When true a [CircularProgressIndicator] is shown instead of the play/pause
  /// icon.  Used while the player is restoring state from disk.
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
  State<AnimatedPlayPauseIcon> createState() => _AnimatedPlayPauseIconState();
}

class _AnimatedPlayPauseIconState extends State<AnimatedPlayPauseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(AnimatedPlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.color),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        widget.isPlaying ? LucideIcons.pause : LucideIcons.play,
        key: ValueKey(widget.isPlaying),
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}
