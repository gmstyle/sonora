import 'package:material_ui/material_ui.dart';

/// Single-line title that scrolls when it is wider than the available space.
///
/// With [reduceEffects], an overflowing title stays clipped with an ellipsis.
class OverflowTitle extends StatelessWidget {
  const OverflowTitle({
    super.key,
    required this.text,
    required this.style,
    this.reduceEffects = false,
  });

  final String text;
  final TextStyle? style;
  final bool reduceEffects;

  static const blankSpace = 48.0;
  static const velocity = 40.0;
  static const pauseAfterRound = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: double.infinity);

        final fits =
            !maxWidth.isFinite || painter.width <= maxWidth || reduceEffects;
        if (fits) {
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return SizedBox(
          width: maxWidth,
          height: painter.height,
          child: _ScrollingTitle(
            text: text,
            style: style,
            textWidth: painter.width,
            viewportWidth: maxWidth,
          ),
        );
      },
    );
  }
}

class _ScrollingTitle extends StatefulWidget {
  const _ScrollingTitle({
    required this.text,
    required this.style,
    required this.textWidth,
    required this.viewportWidth,
  });

  final String text;
  final TextStyle? style;
  final double textWidth;
  final double viewportWidth;

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void didUpdateWidget(covariant _ScrollingTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textWidth != widget.textWidth) {
      _controller.duration = _cycle;
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration get _cycle {
    final distance = widget.textWidth + OverflowTitle.blankSpace;
    final scrollMs = (distance / OverflowTitle.velocity * 1000).round();
    return OverflowTitle.pauseAfterRound + Duration(milliseconds: scrollMs);
  }

  double _offset(double distance) {
    final totalMs = _cycle.inMilliseconds;
    final pauseMs = OverflowTitle.pauseAfterRound.inMilliseconds;
    final elapsed = _controller.value * totalMs;
    if (elapsed <= pauseMs || totalMs <= pauseMs) return 0;
    final progress = (elapsed - pauseMs) / (totalMs - pauseMs);
    return -distance * progress;
  }

  @override
  Widget build(BuildContext context) {
    final distance = widget.textWidth + OverflowTitle.blankSpace;
    Text label() =>
        Text(widget.text, style: widget.style, maxLines: 1, softWrap: false);

    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return const LinearGradient(
            colors: [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0, 0.05, 0.9, 1],
          ).createShader(
            Rect.fromLTWH(0, 0, widget.viewportWidth, bounds.height),
          );
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_offset(distance), 0),
              child: child,
            );
          },
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                label(),
                const SizedBox(width: OverflowTitle.blankSpace),
                label(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
