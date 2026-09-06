import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sonora/core/extensions/duration_ext.dart';

/// Track thickness and whether times sit beside or below the bar.
enum ProgressBarDensity {
  /// Dock / rail / sidebar: 2px fill, no thumb at rest, no times.
  compact,

  /// Wide mini: 3px track, times beside, thumb on hover/scrub.
  comfortable,

  /// Full player: 4px track, times below, thumb always, grows on scrub.
  expanded,
}

/// Thin streaming-style seek bar (Spotify / YouTube Music).
class ProgressBarWidget extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;
  final bool disabled;
  final bool isPlaying;
  final ProgressBarDensity density;

  const ProgressBarWidget({
    super.key,
    required this.position,
    required this.duration,
    this.onSeek,
    this.disabled = false,
    this.isPlaying = false,
    this.density = ProgressBarDensity.expanded,
  });

  bool get seekable => onSeek != null && !disabled;

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget>
    with SingleTickerProviderStateMixin {
  double? _dragProgress;
  bool _hovering = false;
  late final AnimationController _scrub;

  @override
  void initState() {
    super.initState();
    _scrub = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _scrub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalMs = widget.duration.inMilliseconds;
    final progress = (_dragProgress ??
            (totalMs > 0 ? widget.position.inMilliseconds / totalMs : 0.0))
        .clamp(0.0, 1.0);
    final preview = _previewPosition(totalMs);
    final remaining =
        widget.duration > preview ? widget.duration - preview : Duration.zero;

    final trackHeight = switch (widget.density) {
      ProgressBarDensity.compact => 2.0,
      ProgressBarDensity.comfortable => 3.0,
      ProgressBarDensity.expanded => 4.0,
    };
    final restThumb = switch (widget.density) {
      ProgressBarDensity.compact => 0.0,
      ProgressBarDensity.comfortable => 0.0,
      ProgressBarDensity.expanded => 5.0,
    };
    final activeThumb = switch (widget.density) {
      ProgressBarDensity.compact => 4.0,
      ProgressBarDensity.comfortable => 8.0,
      ProgressBarDensity.expanded => 10.0,
    };
    final barHeight = switch (widget.density) {
      ProgressBarDensity.compact => widget.seekable ? 16.0 : 6.0,
      ProgressBarDensity.comfortable => 20.0,
      ProgressBarDensity.expanded => 24.0,
    };

    final bar = AnimatedBuilder(
      animation: _scrub,
      builder: (context, child) {
        final thumb = ui.lerpDouble(restThumb, activeThumb, _scrub.value)!;
        return CustomPaint(
          size: Size.fromHeight(barHeight),
          painter: _SeekTrackPainter(
            progress: progress,
            color: cs.primary,
            trackColor: cs.onSurface.withValues(alpha: 0.18),
            trackHeight: trackHeight,
            thumbRadius: thumb,
            thumbFill: cs.onPrimary,
          ),
        );
      },
    );

    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.0,
      fontSize: widget.density == ProgressBarDensity.comfortable ? 11 : 12,
    );

    Widget track = bar;
    if (widget.seekable) {
      track = _seekGesture(child: bar);
      if (widget.density != ProgressBarDensity.compact) {
        track = MouseRegion(
          onEnter: (_) {
            setState(() => _hovering = true);
            _scrub.forward();
          },
          onExit: (_) {
            setState(() => _hovering = false);
            if (_dragProgress == null) _scrub.reverse();
          },
          child: track,
        );
      }
    }

    if (widget.density == ProgressBarDensity.comfortable) {
      return Row(
        children: [
          Text(preview.format(), style: timeStyle),
          const SizedBox(width: 8),
          Expanded(child: track),
          const SizedBox(width: 8),
          Text('-${remaining.format()}', style: timeStyle),
        ],
      );
    }
    if (widget.density == ProgressBarDensity.expanded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          track,
          const SizedBox(height: 6),
          Row(
            children: [
              Text(preview.format(), style: timeStyle),
              const Spacer(),
              Text('-${remaining.format()}', style: timeStyle),
            ],
          ),
        ],
      );
    }
    return track;
  }

  Duration _previewPosition(int totalMs) {
    if (_dragProgress != null && totalMs > 0) {
      return Duration(milliseconds: (_dragProgress! * totalMs).toInt());
    }
    return widget.position;
  }

  Widget _seekGesture({required Widget child}) {
    final totalMs = widget.duration.inMilliseconds;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            HapticFeedback.selectionClick();
            _previewDrag(details.localPosition.dx, width, totalMs);
          },
          onHorizontalDragUpdate:
              (details) =>
                  _previewDrag(details.localPosition.dx, width, totalMs),
          onHorizontalDragEnd: (_) => _commitSeek(totalMs),
          onHorizontalDragCancel: _cancelDrag,
          onTapDown:
              (details) =>
                  _previewDrag(details.localPosition.dx, width, totalMs),
          onTapUp: (_) => _commitSeek(totalMs),
          onTapCancel: _cancelDrag,
          child: child,
        );
      },
    );
  }

  void _previewDrag(double dx, double width, int totalMs) {
    if (totalMs <= 0 || width <= 0) return;
    if (_dragProgress == null) {
      _scrub.forward();
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
    if (!_hovering) _scrub.reverse();
    widget.onSeek?.call(seekTo);
  }

  void _cancelDrag() {
    if (_dragProgress == null) return;
    setState(() {
      _dragProgress = null;
    });
    if (!_hovering) _scrub.reverse();
  }
}

class _SeekTrackPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double trackHeight;
  final double thumbRadius;
  final Color thumbFill;

  _SeekTrackPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.trackHeight,
    required this.thumbRadius,
    required this.thumbFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final y = size.height / 2;
    if (w <= 0) return;

    final inset = thumbRadius;
    final left = inset;
    final right = w - inset;
    final span = (right - left).clamp(0.0, w);
    final playX = left + progress.clamp(0.0, 1.0) * span;

    final trackPaint =
        Paint()
          ..color = trackColor
          ..strokeWidth = trackHeight
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(left, y), Offset(right, y), trackPaint);

    if (progress > 0 && span > 0) {
      canvas.drawLine(
        Offset(left, y),
        Offset(playX, y),
        Paint()
          ..color = color
          ..strokeWidth = trackHeight
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    if (thumbRadius > 0.5) {
      canvas.drawCircle(Offset(playX, y), thumbRadius, Paint()..color = color);
      canvas.drawCircle(
        Offset(playX, y),
        thumbRadius * 0.38,
        Paint()..color = thumbFill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeekTrackPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor ||
        trackHeight != oldDelegate.trackHeight ||
        thumbRadius != oldDelegate.thumbRadius ||
        thumbFill != oldDelegate.thumbFill;
  }
}
