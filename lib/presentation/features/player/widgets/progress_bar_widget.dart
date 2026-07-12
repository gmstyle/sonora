import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sonora/core/extensions/duration_ext.dart';

class ProgressBarWidget extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final int seed;
  final ValueChanged<Duration>? onSeek;
  final bool disabled;
  final bool isPlaying;
  final bool isMini;

  const ProgressBarWidget({
    super.key,
    required this.position,
    required this.duration,
    this.seed = 0,
    this.onSeek,
    this.disabled = false,
    this.isPlaying = false,
    this.isMini = false,
  });

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget>
    with TickerProviderStateMixin {
  double? _dragProgress;
  late final AnimationController _animationController;
  late final AnimationController _scrubController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 4,
      ), // Loop duration for a smooth waves flow
    );
    _scrubController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    if (widget.isPlaying && !widget.disabled) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ProgressBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.disabled != oldWidget.disabled) {
      if (widget.isPlaying && !widget.disabled) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMini) {
      final totalMs = widget.duration.inMilliseconds;
      final posMs = widget.position.inMilliseconds;
      final progress = totalMs > 0 ? posMs / totalMs : 0.0;

      final theme = Theme.of(context);
      final color = theme.colorScheme.primary;

      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size.fromHeight(
                6.0,
              ), // very sleek height for mini player
              painter: _LiquidWavePainter(
                progress: progress,
                color: color,
                animationValue: _animationController.value,
                isPlaying: widget.isPlaying && !widget.disabled,
                scrubValue: 0.0,
                timeText: '',
                textStyle: const TextStyle(),
                isMini: true,
              ),
            );
          },
        ),
      );
    }

    final totalMs = widget.duration.inMilliseconds;
    final posMs = widget.position.inMilliseconds;
    final progress = _dragProgress ?? (totalMs > 0 ? posMs / totalMs : 0.0);

    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    final hasHours = widget.duration.inHours > 0;
    final timeWidth = hasHours ? 64.0 : 45.0;

    final currentDuration =
        _dragProgress != null
            ? Duration(milliseconds: (_dragProgress! * totalMs).toInt())
            : widget.position;
    final currentText = currentDuration.format();

    return AnimatedBuilder(
      animation: _scrubController,
      builder: (context, child) {
        // Timings fade to full opacity when scrubbing
        final timeOpacity = ui.lerpDouble(0.6, 1.0, _scrubController.value)!;
        final timeStyle = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: timeOpacity,
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Current position / drag preview time
            SizedBox(
              width: timeWidth,
              child: Text(
                currentText,
                style: timeStyle,
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(width: 8),
            // Progress wave seekbar
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart:
                        widget.disabled
                            ? null
                            : (details) {
                              _previewDrag(
                                details.localPosition.dx,
                                width,
                                totalMs,
                              );
                            },
                    onHorizontalDragUpdate:
                        widget.disabled
                            ? null
                            : (details) {
                              _previewDrag(
                                details.localPosition.dx,
                                width,
                                totalMs,
                              );
                            },
                    onHorizontalDragEnd:
                        widget.disabled ? null : (_) => _commitSeek(totalMs),
                    onTapDown:
                        widget.disabled
                            ? null
                            : (details) {
                              _previewDrag(
                                details.localPosition.dx,
                                width,
                                totalMs,
                              );
                            },
                    onTapUp:
                        widget.disabled ? null : (_) => _commitSeek(totalMs),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _animationController,
                          _scrubController,
                        ]),
                        builder: (context, child) {
                          // The height expands from 36 to 64 pixels to house the wave and floating tooltip
                          final double currentHeight =
                              36.0 + _scrubController.value * 28.0;
                          return CustomPaint(
                            size: Size.fromHeight(currentHeight),
                            painter: _LiquidWavePainter(
                              progress: progress,
                              color: color,
                              animationValue: _animationController.value,
                              isPlaying: widget.isPlaying && !widget.disabled,
                              scrubValue: _scrubController.value,
                              timeText: currentText,
                              textStyle:
                                  theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                              isMini: false,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // Total duration time
            SizedBox(
              width: timeWidth,
              child: Text(
                widget.duration.format(),
                style: timeStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    );
  }

  void _previewDrag(double dx, double width, int totalMs) {
    if (totalMs <= 0 || width <= 0) return;
    if (_dragProgress == null) {
      _scrubController.forward();
    }
    setState(() {
      _dragProgress = (dx / width).clamp(0.0, 1.0);
    });
  }

  void _commitSeek(int totalMs) {
    if (_dragProgress == null) return;
    final seekTo = Duration(milliseconds: (_dragProgress! * totalMs).toInt());
    setState(() {
      _dragProgress = null;
    });
    _scrubController.reverse();
    widget.onSeek?.call(seekTo);
  }
}

class _LiquidWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double animationValue;
  final bool isPlaying;
  final double scrubValue;
  final String timeText;
  final TextStyle textStyle;
  final bool isMini;

  _LiquidWavePainter({
    required this.progress,
    required this.color,
    required this.animationValue,
    required this.isPlaying,
    required this.scrubValue,
    required this.timeText,
    required this.textStyle,
    required this.isMini,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isMini) {
      final double baselineY = size.height / 2;
      final double barThickness = 2.0;
      final double width = size.width;
      final double playheadX = progress * width;

      // 1. Paint Background Track (Inactive)
      final trackPaint =
          Paint()
            ..color = color.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill;

      final trackRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          0,
          baselineY - barThickness / 2,
          width,
          baselineY + barThickness / 2,
        ),
        Radius.circular(barThickness / 2),
      );
      canvas.drawRRect(trackRRect, trackPaint);

      // 2. Paint Active Waves (Mini version: smaller amplitude, higher density)
      if (progress > 0) {
        final double baseAmplitude = 1.8;
        final double waveSpeedMultiplier = isPlaying ? 1.0 : 0.0;
        final double currentPhase =
            animationValue * 2 * math.pi * waveSpeedMultiplier;

        // Wave 1
        _drawWave(
          canvas: canvas,
          width: playheadX,
          baselineY: baselineY,
          barThickness: barThickness,
          amplitude: baseAmplitude,
          frequency: 0.12,
          phase: currentPhase,
          paint:
              Paint()
                ..color = color.withValues(alpha: 0.8)
                ..style = PaintingStyle.fill,
        );

        // Wave 2
        _drawWave(
          canvas: canvas,
          width: playheadX,
          baselineY: baselineY,
          barThickness: barThickness,
          amplitude: baseAmplitude * 0.7,
          frequency: 0.16,
          phase: currentPhase + math.pi / 2,
          paint:
              Paint()
                ..color = color.withValues(alpha: 0.4)
                ..style = PaintingStyle.fill,
        );
      }
      return;
    }

    // ── Layout Geometry ──────────────────────────────────────────
    // When idle (scrubValue = 0), baselineY is in the middle (size.height / 2).
    // When scrubbing (scrubValue = 1), baselineY is shifted lower (size.height - 12.0).
    final double baselineY =
        ui.lerpDouble(size.height / 2, size.height - 12.0, scrubValue)!;

    // The bar thickness increases slightly when scrubbing
    final double barThickness = ui.lerpDouble(3.0, 6.0, scrubValue)!;

    final double width = size.width;
    final double playheadX = progress * width;

    // ── 1. Paint Background Track (Inactive) ─────────────────────
    final trackPaint =
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;

    final trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        0,
        baselineY - barThickness / 2,
        width,
        baselineY + barThickness / 2,
      ),
      Radius.circular(barThickness / 2),
    );
    canvas.drawRRect(trackRRect, trackPaint);

    // ── 2. Paint Active Waves ────────────────────────────────────
    if (progress > 0) {
      // Wave config: Base wave amplitude scales up when scrubbing (larger bounds)
      final double baseAmplitude = ui.lerpDouble(6.0, 12.0, scrubValue)!;
      final double waveSpeedMultiplier = isPlaying ? 1.0 : 0.0;
      final double currentPhase =
          animationValue * 2 * math.pi * waveSpeedMultiplier;

      // We draw two waves with different phases and opacities
      // Wave 1: primary color, higher opacity
      _drawWave(
        canvas: canvas,
        width: playheadX,
        baselineY: baselineY,
        barThickness: barThickness,
        amplitude: baseAmplitude,
        frequency: 0.06,
        phase: currentPhase,
        paint:
            Paint()
              ..color = color.withValues(alpha: 0.8)
              ..style = PaintingStyle.fill,
      );

      // Wave 2: primary color, lower opacity, shifted phase and frequency
      _drawWave(
        canvas: canvas,
        width: playheadX,
        baselineY: baselineY,
        barThickness: barThickness,
        amplitude: baseAmplitude * 0.7,
        frequency: 0.09,
        phase: currentPhase + math.pi / 2,
        paint:
            Paint()
              ..color = color.withValues(alpha: 0.4)
              ..style = PaintingStyle.fill,
      );
    }

    // ── 3. Paint Playhead Bead and Glow ──────────────────────────
    // The bead scales up when scrubbing
    final double beadRadius = ui.lerpDouble(5.0, 9.0, scrubValue)!;

    // Pulsing heartbeat factor when playing (affects the glow)
    final double heartbeat =
        isPlaying
            ? 0.5 +
                0.5 *
                    math.sin(
                      animationValue * 2 * math.pi * 2,
                    ) // 2x speed heartbeat
            : 0.0;

    // Draw radial neon glow
    final glowPaint =
        Paint()
          ..color = color.withValues(
            alpha: ui.lerpDouble(0.1, 0.3, scrubValue)! + 0.15 * heartbeat,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            ui.lerpDouble(4.0, 8.0, scrubValue)! + 2 * heartbeat,
          );

    canvas.drawCircle(
      Offset(playheadX, baselineY),
      beadRadius * (1.6 + 0.3 * heartbeat),
      glowPaint,
    );

    // Draw main playhead circle
    final beadPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(playheadX, baselineY), beadRadius, beadPaint);

    // Draw playhead inner dot (primary accent color)
    final innerDotPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(playheadX, baselineY),
      beadRadius * 0.45,
      innerDotPaint,
    );

    // ── 4. Paint Floating Tooltip Bubble (Scrubbing Only) ────────
    if (scrubValue > 0.0) {
      final double tooltipOpacity = scrubValue;

      // Build text painter
      final TextPainter tp = TextPainter(
        text: TextSpan(text: timeText, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      // Tooltip position: sitting above the playhead.
      final double bubbleHeight = 18.0;
      final double bubbleWidth = tp.width + 12.0;
      final double bubbleBottomY =
          baselineY - beadRadius - ui.lerpDouble(4.0, 10.0, scrubValue)!;
      final double bubbleTopY = bubbleBottomY - bubbleHeight;

      // Clamp bubble horizontal position within canvas bounds
      final double halfWidth = bubbleWidth / 2;
      final double bubbleCenterX = playheadX.clamp(
        halfWidth,
        width - halfWidth,
      );

      final Rect bubbleRect = Rect.fromLTRB(
        bubbleCenterX - halfWidth,
        bubbleTopY,
        bubbleCenterX + halfWidth,
        bubbleBottomY,
      );

      final Path bubblePath = Path();
      // Draw rounded rectangle
      final RRect roundedRect = RRect.fromRectAndRadius(
        bubbleRect,
        const Radius.circular(5),
      );
      bubblePath.addRRect(roundedRect);

      // Draw downward pointer triangle centered over the playhead
      final double triangleSize = 4.0;
      bubblePath.moveTo(playheadX - triangleSize, bubbleBottomY);
      bubblePath.lineTo(playheadX, bubbleBottomY + triangleSize);
      bubblePath.lineTo(playheadX + triangleSize, bubbleBottomY);
      bubblePath.close();

      // Paint tooltip bubble
      final bubblePaint =
          Paint()
            ..color = color.withValues(alpha: tooltipOpacity)
            ..style = PaintingStyle.fill;

      canvas.drawPath(bubblePath, bubblePaint);

      // Paint current time text inside bubble
      tp.paint(
        canvas,
        Offset(
          bubbleCenterX - tp.width / 2,
          bubbleTopY + (bubbleHeight - tp.height) / 2,
        ),
      );
    }
  }

  /// Draws a wave path from x = 0 to x = width (playheadX), closed at the baseline.
  void _drawWave({
    required Canvas canvas,
    required double width,
    required double baselineY,
    required double barThickness,
    required double amplitude,
    required double frequency,
    required double phase,
    required Paint paint,
  }) {
    final path = Path();

    // Wave starting point
    path.moveTo(0, baselineY + barThickness / 2);

    // Generate sinusoidal points along the track width
    const double step = 2.0;
    for (double x = 0; x <= width; x += step) {
      final double y = baselineY - math.sin(x * frequency + phase) * amplitude;
      path.lineTo(x, y);
    }

    // Connect back to baseline at the right side (playhead position)
    path.lineTo(width, baselineY + barThickness / 2);
    // Connect to baseline at the left side
    path.lineTo(0, baselineY + barThickness / 2);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        animationValue != oldDelegate.animationValue ||
        isPlaying != oldDelegate.isPlaying ||
        scrubValue != oldDelegate.scrubValue ||
        timeText != oldDelegate.timeText ||
        textStyle != oldDelegate.textStyle ||
        isMini != oldDelegate.isMini;
  }
}
