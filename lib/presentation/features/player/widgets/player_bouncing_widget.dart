import 'dart:math';
import 'dart:ui' as ui;
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/palette_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import 'player_shared_widgets.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;
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

class PlayerDefaultView extends ConsumerStatefulWidget {
  final bool tight;
  final double? size;
  final bool showFlipIndicator;

  const PlayerDefaultView({
    super.key,
    this.tight = false,
    this.size,
    this.showFlipIndicator = false,
  });

  @override
  ConsumerState<PlayerDefaultView> createState() => _PlayerDefaultViewState();
}

class _PlayerDefaultViewState extends ConsumerState<PlayerDefaultView>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _timerFade;
  late Animation<double> _timerSlide;
  late Animation<double> _visualizerFade;
  late Animation<double> _visualizerScale;
  late Animation<double> _upNextFade;
  late Animation<double> _upNextSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _timerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _timerSlide = Tween<double>(begin: -15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _visualizerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _visualizerScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.75, curve: Curves.elasticOut),
      ),
    );

    _upNextFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );
    _upNextSlide = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final videoId = currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final isPlaying = playerState.isPlaying && !playerState.isLoading;
    final theme = Theme.of(context);
    final pc = PlayerColors.of(context);

    // Get dominant color for the visualizer
    final paletteMap = ref.watch(paletteNotifierProvider);
    final paletteData = paletteMap[videoId];
    final dominantColor =
        paletteData?.dominantColor ?? theme.colorScheme.primary;

    // Sleep Timer
    final remaining = playerState.sleepTimerRemaining;

    // Up Next — we display the first upnext item if any. The card is
    // always rendered (even when the upnext section is empty) so the
    // user sees the autoplay status ("attivo" / "disattivato") and can
    // toggle it inline.
    final upNextQueue = playerState.upNextQueue;
    final nextSong = upNextQueue.isNotEmpty ? upNextQueue.first : null;
    final hasNext = nextSong != null;

    final clampedSize = widget.size?.clamp(150.0, 600.0);

    final viewContent = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (remaining != null) ...[
              AnimatedBuilder(
                animation: _entranceController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _timerFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _timerSlide.value),
                      child: child,
                    ),
                  );
                },
                child: _buildTimerBadge(context, ref, remaining),
              ),
              SizedBox(height: widget.tight ? 8 : 32),
            ],
            AnimatedBuilder(
              animation: _entranceController,
              builder: (context, child) {
                return Opacity(
                  opacity: _visualizerFade.value,
                  child: Transform.scale(
                    scale: _visualizerScale.value,
                    child: child,
                  ),
                );
              },
              child: AudioVisualizer(
                isPlaying: isPlaying,
                color: dominantColor,
                height: widget.tight ? 40 : 70,
              ),
            ),
            if (!widget.tight) ...[
              const SizedBox(height: 48),
              AnimatedBuilder(
                animation: _entranceController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _upNextFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _upNextSlide.value),
                      child: child,
                    ),
                  );
                },
                child: _buildUpNextCard(context, ref, nextSong, pc, hasNext),
              ),
            ],
          ],
        ),
      ),
    );

    if (clampedSize == null) {
      return viewContent;
    }

    return SizedBox(
      width: clampedSize,
      height: clampedSize,
      child: Stack(
        children: [
          Positioned.fill(child: viewContent),
          if (widget.showFlipIndicator)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Icon(
                  LucideIcons.image,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerBadge(
    BuildContext context,
    WidgetRef ref,
    Duration remaining,
  ) {
    final pc = PlayerColors.of(context);
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return BouncingWidget(
      onTap:
          () => showPlayerTimerDialog(
            context,
            ref.read(playerStateProvider.notifier),
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.timer,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: pc.titlePrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpNextCard(
    BuildContext context,
    WidgetRef ref,
    MediaItem? nextSong,
    PlayerColors pc,
    bool hasNext,
  ) {
    final theme = Theme.of(context);
    final isAutoplay = ref.watch(
      settingsProvider.select((s) => s.autoPlayUpNext),
    );

    return BouncingWidget(
      onTap:
          hasNext
              ? () {
                ref.read(playerStateProvider.notifier).skipToNext();
              }
              : null,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetIn = Tween<Offset>(
                    begin: const Offset(0.15, 0.0),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offsetIn, child: child),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: <Widget>[
                      ...previousChildren.map((c) => Positioned.fill(child: c)),
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _buildUpNextCardContent(
                  context,
                  nextSong,
                  pc,
                  hasNext,
                  isAutoplay,
                  theme,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpNextCardContent(
    BuildContext context,
    MediaItem? nextSong,
    PlayerColors pc,
    bool hasNext,
    bool isAutoplay,
    ThemeData theme,
  ) {
    // We key the content based on nextSong ID to trigger transitions in AnimatedSwitcher.
    final keyString =
        nextSong != null ? nextSong.id : 'empty_${isAutoplay}_$hasNext';

    return Row(
      key: ValueKey(keyString),
      children: [
        if (hasNext && nextSong != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child:
                  nextSong.artUri != null
                      ? CachedNetworkImage(
                        imageUrl: nextSong.artUri!.toString(),
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, _, _) => Icon(
                              LucideIcons.music,
                              color: pc.iconSecondary,
                              size: 28,
                            ),
                      )
                      : Icon(
                        LucideIcons.music,
                        color: pc.iconSecondary,
                        size: 28,
                      ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.upNext.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pc.labelMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const PulsingDot(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nextSong.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: pc.titlePrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nextSong.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: pc.subtitle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(LucideIcons.skipForward, color: pc.iconSecondary, size: 22),
        ] else ...[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAutoplay ? LucideIcons.infinity : LucideIcons.music,
              color: pc.iconSecondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAutoplay ? 'AUTOPLAY' : 'FINE CODA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pc.labelMuted,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAutoplay
                      ? 'Riproduzione automatica attiva'
                      : AppLocalizations.of(context)!.noUpcomingSongs,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: pc.titleSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isAutoplay)
            TextButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setAutoPlayUpNext(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: pc.iconPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(AppLocalizations.of(context)!.autoplayEnable),
            ),
        ],
      ],
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
    final double glowAlpha =
        widget.isPlaying ? 0.35 * (heightFactor / _amplitudes[index]) : 0.0;

    return Container(
      width: 6,
      height: widget.height * heightFactor,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(3),
        boxShadow:
            glowAlpha > 0.01
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
