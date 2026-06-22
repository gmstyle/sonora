import 'package:flutter/material.dart';
import 'package:sonora/core/extensions/duration_ext.dart';

class ProgressBarWidget extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final int seed;
  final ValueChanged<Duration>? onSeek;

  /// When true all drag/tap gestures are ignored and the bar renders the
  /// [position] as a static indicator.  Used while the player is restoring.
  final bool disabled;

  const ProgressBarWidget({
    super.key,
    required this.position,
    required this.duration,
    this.seed = 0,
    this.onSeek,
    this.disabled = false,
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
                // ── Drag: show preview position while dragging, seek only on release.
                // Committing a seek on every drag update causes the player to
                // re-buffer from the new position on each pixel, producing
                // continuous buffering during scrubbing.  All major players
                // (Spotify, YouTube Music) update the indicator in real time but
                // send a single seek when the finger lifts.
                onHorizontalDragStart:
                    widget.disabled
                        ? null
                        : (details) {
                          _previewDrag(details.localPosition.dx, width, totalMs);
                        },
                onHorizontalDragUpdate:
                    widget.disabled
                        ? null
                        : (details) {
                          _previewDrag(details.localPosition.dx, width, totalMs);
                        },
                onHorizontalDragEnd:
                    widget.disabled
                        ? null
                        : (_) => _commitSeek(totalMs),
                // ── Tap: preview on down for instant visual feedback,
                //    commit the seek once on up.  Previously both events called
                //    onSeek, resulting in two redundant seeks per tap.
                onTapDown:
                    widget.disabled
                        ? null
                        : (details) {
                          _previewDrag(details.localPosition.dx, width, totalMs);
                        },
                onTapUp:
                    widget.disabled
                        ? null
                        : (_) => _commitSeek(totalMs),
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

  /// Updates the visual preview position without sending a seek command.
  void _previewDrag(double dx, double width, int totalMs) {
    if (totalMs <= 0 || width <= 0) return;
    setState(() {
      _dragProgress = (dx / width).clamp(0.0, 1.0);
    });
  }

  /// Commits the seek command at the current preview position, then clears it.
  void _commitSeek(int totalMs) {
    if (_dragProgress == null) return;
    final seekTo = Duration(milliseconds: (_dragProgress! * totalMs).toInt());
    setState(() {
      _dragProgress = null;
    });
    widget.onSeek?.call(seekTo);
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
    // seed must be included: skipping to a new track can leave progress == 0.0
    // and color unchanged, but the waveform shape is determined by seed alone.
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        seed != oldDelegate.seed;
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
