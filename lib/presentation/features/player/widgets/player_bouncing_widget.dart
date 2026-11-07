import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/player_colors.dart';

/// A custom widget that handles a springy scale-down tactile effect when tapped.
class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BouncingWidget({super.key, required this.child, this.onTap});

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// A subtle pulsing dot indicator for active up next items.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        PlayerColors.maybeOf(context)?.accent ?? PlayerColors.standard().accent;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(
              alpha: 0.3 + 0.7 * _controller.value,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.4 * _controller.value),
                blurRadius: 4 * _controller.value,
                spreadRadius: 1 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    required this.color,
    this.height = 70,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double _time = 0.0;
  double _lastValue = 0.0;
  double _currentSpeed = 0.2;

  // Constants to define unique organic waveforms for 16 bars
  final List<double> _frequencies = [
    0.8,
    1.5,
    2.2,
    1.1,
    1.9,
    2.7,
    1.4,
    2.0,
    2.0,
    1.4,
    2.7,
    1.9,
    1.1,
    2.2,
    1.5,
    0.8,
  ];
  final List<double> _secondaryFrequencies = [
    0.4,
    0.7,
    1.1,
    0.5,
    0.9,
    1.3,
    0.7,
    1.0,
    1.0,
    0.7,
    1.3,
    0.9,
    0.5,
    1.1,
    0.7,
    0.4,
  ];
  final List<double> _amplitudes = [
    0.35,
    0.5,
    0.65,
    0.8,
    0.9,
    0.95,
    1.0,
    1.0,
    1.0,
    1.0,
    0.95,
    0.9,
    0.8,
    0.65,
    0.5,
    0.35,
  ];

  @override
  void initState() {
    super.initState();
    // Use a long looping duration to keep it continuously animating smoothly
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _lastValue = _controller.value;
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final double currentVal = _controller.value;
    double delta = currentVal - _lastValue;
    if (delta < 0) {
      delta += 1.0;
    }
    _lastValue = currentVal;

    // Smoothly transition between speed for play vs. pause (breathing)
    final double targetSpeed = widget.isPlaying ? 2.5 : 0.15;
    _currentSpeed =
        ui.lerpDouble(_currentSpeed, targetSpeed, 0.08) ?? targetSpeed;

    _time += delta * _currentSpeed * 2 * pi;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  /// Ensures that the color used has a minimum brightness level, preventing
  /// visualizer bars from disappearing against a dark background when the
  /// dominant color extracted from the album artwork is extremely dark or black.
  Color _getVibrantColor(Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);

    // If color is too dark, boost its brightness value to make it stand out
    if (hsv.value < 0.6) {
      return hsv
          .withValue(0.85)
          .withSaturation(max(hsv.saturation, 0.6))
          .toColor();
    }
    // If color is highly desaturated, boost saturation for visibility
    if (hsv.saturation < 0.25) {
      return hsv.withSaturation(0.6).withValue(0.9).toColor();
    }
    return baseColor;
  }

  @override
  Widget build(BuildContext context) {
    final vibrantColor = _getVibrantColor(widget.color);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(16, (index) {
        // Multi-frequency wave synthesis for organic sound simulation
        final double wave1 = sin(_time * _frequencies[index]);
        final double wave2 = cos(
          _time * _secondaryFrequencies[index] + index * 0.5,
        );
        double factor = (wave1 * 0.65 + wave2 * 0.35).abs();

        // Baseline minimum amplitude
        factor = 0.15 + 0.85 * factor;

        // Multiply by the shape envelope
        final double heightFactor = factor * _amplitudes[index];

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Background track behind each bar: defines boundaries and
            // ensures the visualizer shape is elegantly visible even at rest.
            Container(
              width: 6,
              height: widget.height * _amplitudes[index],
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: vibrantColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Glowing visualizer bar
            _buildBar(index, heightFactor, vibrantColor),
          ],
        );
      }),
    );
  }

  Widget _buildBar(int index, double heightFactor, Color vibrantColor) {
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        vibrantColor.withValues(alpha: 0.35),
        vibrantColor.withValues(alpha: 0.95),
      ],
    );

    // Dynamic glow shadow opacity based on height and playing status
    final double glowAlpha = widget.isPlaying
        ? 0.35 * (heightFactor / _amplitudes[index])
        : 0.0;

    return Container(
      width: 6,
      height: widget.height * heightFactor,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(3),
        boxShadow: glowAlpha > 0.01
            ? [
                BoxShadow(
                  color: vibrantColor.withValues(alpha: glowAlpha),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}
