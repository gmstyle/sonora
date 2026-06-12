import 'package:flutter/material.dart';
import 'package:sonora/core/extensions/duration_ext.dart';

class ProgressBarWidget extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final int seed;
  final ValueChanged<Duration>? onSeek;

  const ProgressBarWidget({
    super.key,
    required this.position,
    required this.duration,
    this.seed = 0,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final posMs = position.inMilliseconds;
    final progress = totalMs > 0 ? posMs / totalMs : 0.0;

    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              size: Size.fromHeight(40),
              painter: _WaveformPainter(
                progress: progress,
                color: color,
                seed: seed,
              ),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.24),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: posMs.toDouble().clamp(0, totalMs.toDouble()),
            max: totalMs > 0 ? totalMs.toDouble() : 1.0,
            onChanged: (v) => onSeek?.call(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                position.format(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                duration.format(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int seed;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = _SeededRng(seed);
    final barCount = (size.width / 5).floor();
    final barWidth = (size.width / barCount) - 1;

    for (int i = 0; i < barCount; i++) {
      final fraction = i / barCount;
      final barHeight = (0.2 + rng.nextDouble() * 0.8) * size.height;
      final x = i * (barWidth + 1);
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(1),
      );

      if (fraction < progress) {
        canvas.drawRRect(rect, Paint()..color = color);
      } else {
        canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.24));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}

class _SeededRng {
  int _state;

  _SeededRng(int seed) : _state = seed.abs() + 1;

  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}
