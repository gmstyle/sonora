import 'package:flutter/material.dart';
import 'package:sonora/core/extensions/duration_ext.dart';

class ProgressBarWidget extends StatefulWidget {
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
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final progress = _dragProgress ?? (totalMs > 0 ? posMs / totalMs : 0.0);

    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  _updateDrag(details.localPosition.dx, width, totalMs);
                },
                onHorizontalDragUpdate: (details) {
                  _updateDrag(details.localPosition.dx, width, totalMs);
                },
                onHorizontalDragEnd: (details) {
                  _finalizeDrag(totalMs);
                },
                onTapDown: (details) {
                  _updateDrag(details.localPosition.dx, width, totalMs);
                },
                onTapUp: (details) {
                  _finalizeDrag(totalMs);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CustomPaint(
                    size: const Size.fromHeight(50),
                    painter: _WaveformPainter(
                      progress: progress,
                      color: color,
                      seed: widget.seed,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dragProgress != null
                    ? Duration(
                      milliseconds: (_dragProgress! * totalMs).toInt(),
                    ).format()
                    : widget.position.format(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                widget.duration.format(),
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

  void _updateDrag(double dx, double width, int totalMs) {
    if (totalMs <= 0 || width <= 0) return;
    final newProgress = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = newProgress;
    });
    widget.onSeek?.call(
      Duration(milliseconds: (newProgress * totalMs).toInt()),
    );
  }

  void _finalizeDrag(int totalMs) {
    if (_dragProgress == null) return;
    final finalDuration = Duration(
      milliseconds: (_dragProgress! * totalMs).toInt(),
    );
    widget.onSeek?.call(finalDuration);
    setState(() {
      _dragProgress = null;
    });
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

    // Draw vertical playhead line
    final playheadX = progress * size.width;
    final playheadPaint =
        Paint()
          ..color = color
          ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );
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
