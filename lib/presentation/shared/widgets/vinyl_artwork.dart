import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import 'thumbnail_widget.dart';
import 'scale_button.dart';

class VinylArtwork extends ConsumerStatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isPlaying;
  final bool useShadow;
  final VoidCallback? onTap;
  final String? tooltipMessage;

  const VinylArtwork({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.isPlaying,
    this.useShadow = true,
    this.onTap,
    this.tooltipMessage,
  });

  @override
  ConsumerState<VinylArtwork> createState() => _VinylArtworkState();
}

class _VinylArtworkState extends ConsumerState<VinylArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.isPlaying && !ref.read(settingsProvider).reduceEffects) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduceEffects = ref.read(settingsProvider).reduceEffects;
    if (reduceEffects) {
      _rotationController.stop();
      return;
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );

    if (reduceEffects && _rotationController.isAnimating) {
      _rotationController.stop();
    } else if (!reduceEffects &&
        widget.isPlaying &&
        !_rotationController.isAnimating) {
      _rotationController.repeat();
    }

    final double centerHoleSize = widget.size * (11 / 48);
    final double centerDotSize = widget.size * (3 / 48);

    Widget disk = RotationTransition(
      turns: _rotationController,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow:
              widget.useShadow
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ThumbnailWidget(
                imageUrl: widget.imageUrl,
                size: widget.size,
                shape: ThumbnailShape.circle,
              ),
              Container(
                width: centerHoleSize,
                height: centerHoleSize,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: centerDotSize,
                    height: centerDotSize,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltipMessage != null) {
      disk = Tooltip(message: widget.tooltipMessage!, child: disk);
    }

    if (widget.onTap != null) {
      disk = ScaleButton(onTap: widget.onTap, child: disk);
    }

    return disk;
  }
}
