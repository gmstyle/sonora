import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../domain/models/artwork_style.dart';
import '../../providers/settings_provider.dart';
import 'thumbnail_widget.dart';
import 'vinyl_artwork.dart';

/// Vinyl, pulse, or bars stage. The plain cover stays with the player chrome.
Widget buildStyledPlayerArt({
  required ArtworkStyle style,
  required String? imageUrl,
  required double size,
  required bool isPlaying,
  required bool mini,
}) {
  switch (style) {
    case ArtworkStyle.plain:
      throw ArgumentError.value(style, 'style', 'Plain cover is player chrome');
    case ArtworkStyle.vinyl:
      return VinylArtwork(
        imageUrl: imageUrl,
        size: size,
        isPlaying: isPlaying,
        useShadow: false,
      );
    case ArtworkStyle.pulse:
      return PulseArtwork(
        imageUrl: imageUrl,
        size: size,
        isPlaying: isPlaying,
        circular: !mini,
        cornerRadius: SonoraPulseTokens.radiusSm,
      );
    case ArtworkStyle.bars:
      return BarsArtwork(
        imageUrl: imageUrl,
        size: size,
        isPlaying: isPlaying,
        cornerRadius: mini
            ? SonoraPulseTokens.radiusSm
            : SonoraPulseTokens.radiusMedia,
      );
  }
}

void _syncPlaybackSpin({
  required AnimationController controller,
  required bool reduceEffects,
  required bool isPlaying,
}) {
  if (reduceEffects || !isPlaying) {
    if (controller.isAnimating) controller.stop();
    return;
  }
  if (!controller.isAnimating) controller.repeat();
}

/// Cover with one accent arc traveling the rim. The photo does not spin.
class PulseArtwork extends ConsumerStatefulWidget {
  const PulseArtwork({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.isPlaying,
    required this.circular,
    this.cornerRadius = SonoraPulseTokens.radiusSm,
  });

  final String? imageUrl;
  final double size;
  final bool isPlaying;

  /// Full player is a circle. Mini player keeps the 12px cover radius.
  final bool circular;
  final double cornerRadius;

  @override
  ConsumerState<PulseArtwork> createState() => _PulseArtworkState();
}

class _PulseArtworkState extends ConsumerState<PulseArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _syncPlaybackSpin(
      controller: _spin,
      reduceEffects: ref.read(settingsProvider).reduceEffects,
      isPlaying: widget.isPlaying,
    );
  }

  @override
  void didUpdateWidget(covariant PulseArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlaybackSpin(
      controller: _spin,
      reduceEffects: ref.read(settingsProvider).reduceEffects,
      isPlaying: widget.isPlaying,
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    _syncPlaybackSpin(
      controller: _spin,
      reduceEffects: reduceEffects,
      isPlaying: widget.isPlaying,
    );

    final stroke = (widget.size * 0.028).clamp(2.0, 6.0);
    final cover = widget.circular
        ? ThumbnailWidget(
            imageUrl: widget.imageUrl,
            size: widget.size,
            shape: ThumbnailShape.circle,
          )
        : ThumbnailWidget(
            imageUrl: widget.imageUrl,
            size: widget.size,
            shape: ThumbnailShape.rounded,
            borderRadius: widget.cornerRadius,
          );

    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          cover,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  return CustomPaint(
                    key: const ValueKey('pulse-arc'),
                    painter: _PulseArcPainter(
                      turns: _spin.value,
                      color: SonoraPulseTokens.primaryContainer,
                      strokeWidth: stroke,
                      circular: widget.circular,
                      cornerRadius: widget.cornerRadius,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseArcPainter extends CustomPainter {
  const _PulseArcPainter({
    required this.turns,
    required this.color,
    required this.strokeWidth,
    required this.circular,
    required this.cornerRadius,
  });

  final double turns;
  final Color color;
  final double strokeWidth;
  final bool circular;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final path = Path();
    if (circular) {
      path.addOval(inset);
    } else {
      final radius = math.max(0.0, cornerRadius - strokeWidth / 2);
      path.addRRect(RRect.fromRectAndRadius(inset, Radius.circular(radius)));
    }
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;
    if (length <= 0) return;

    final start = (turns % 1) * length;
    final sweep = length * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    if (start + sweep <= length) {
      canvas.drawPath(metric.extractPath(start, start + sweep), paint);
      return;
    }
    canvas.drawPath(metric.extractPath(start, length), paint);
    canvas.drawPath(metric.extractPath(0, start + sweep - length), paint);
  }

  @override
  bool shouldRepaint(covariant _PulseArcPainter oldDelegate) {
    return turns != oldDelegate.turns ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        circular != oldDelegate.circular ||
        cornerRadius != oldDelegate.cornerRadius;
  }
}

/// Cover with five brand bars along the bottom, in the logomark rhythm.
class BarsArtwork extends ConsumerStatefulWidget {
  const BarsArtwork({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.isPlaying,
    required this.cornerRadius,
  });

  final String? imageUrl;
  final double size;
  final bool isPlaying;
  final double cornerRadius;

  @override
  ConsumerState<BarsArtwork> createState() => _BarsArtworkState();
}

class _BarsArtworkState extends ConsumerState<BarsArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncPlaybackSpin(
      controller: _spin,
      reduceEffects: ref.read(settingsProvider).reduceEffects,
      isPlaying: widget.isPlaying,
    );
  }

  @override
  void didUpdateWidget(covariant BarsArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlaybackSpin(
      controller: _spin,
      reduceEffects: ref.read(settingsProvider).reduceEffects,
      isPlaying: widget.isPlaying,
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    _syncPlaybackSpin(
      controller: _spin,
      reduceEffects: reduceEffects,
      isPlaying: widget.isPlaying,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ThumbnailWidget(
              imageUrl: widget.imageUrl,
              size: widget.size,
              shape: ThumbnailShape.square,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.36,
                widthFactor: 1,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
              ),
            ),
            AnimatedBuilder(
              animation: _spin,
              builder: (context, _) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: widget.size * 0.08),
                    child: _Bars(
                      size: widget.size,
                      phase: widget.isPlaying && !reduceEffects
                          ? _spin.value
                          : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.size, required this.phase});

  final double size;

  /// Null holds every bar at the rest height.
  final double? phase;

  @override
  Widget build(BuildContext context) {
    final barWidth = (size * 0.045).clamp(2.0, 8.0);
    final gap = barWidth * 0.75;
    final minHeight = size * 0.07;
    final maxHeight = size * 0.24;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < 5; index++) ...[
          if (index > 0) SizedBox(width: gap),
          Container(
            width: barWidth,
            height: _height(index, minHeight, maxHeight),
            decoration: BoxDecoration(
              color: SonoraPulseTokens.primaryContainer,
              borderRadius: BorderRadius.circular(barWidth),
            ),
          ),
        ],
      ],
    );
  }

  double _height(int index, double minHeight, double maxHeight) {
    final phase = this.phase;
    if (phase == null) return minHeight;
    final wave = 0.5 + 0.5 * math.sin(phase * math.pi * 2 + index * 0.9);
    return minHeight + (maxHeight - minHeight) * wave;
  }
}
