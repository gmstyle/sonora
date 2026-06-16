import 'dart:math';
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

class PlayerDefaultView extends ConsumerWidget {
  final bool tight;

  const PlayerDefaultView({super.key, this.tight = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Up Next
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final hasNext = currentIndex + 1 < queue.length;
    final nextSong = hasNext ? queue[currentIndex + 1] : null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (remaining != null) ...[
            _buildTimerBadge(context, ref, remaining),
            SizedBox(height: tight ? 16 : 32),
          ],
          AudioVisualizer(
            isPlaying: isPlaying,
            color: dominantColor,
            height: tight ? 50 : 70,
          ),
          SizedBox(height: tight ? 24 : 48),
          _buildUpNextCard(context, ref, nextSong, pc, hasNext),
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

    return GestureDetector(
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

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:
                hasNext
                    ? () {
                      ref.read(playerStateProvider.notifier).skipToNext();
                    }
                    : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                          Text(
                            AppLocalizations.of(context)!.upNext.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: pc.labelMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
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
                    Icon(
                      LucideIcons.skipForward,
                      color: pc.iconSecondary,
                      size: 22,
                    ),
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
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
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
  final List<double> _baseSpeeds = [
    1.5,
    2.3,
    1.8,
    2.7,
    1.4,
    2.1,
    1.6,
    2.5,
    1.3,
    2.0,
    1.7,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(11, (index) {
            final double progress =
                _controller.value * 2 * pi * _baseSpeeds[index];
            final double heightFactor = (sin(progress) + 1.0) / 2.0;
            final double currentFactor =
                widget.isPlaying ? 0.15 + 0.85 * heightFactor : 0.15;

            return Container(
              width: 6,
              height: widget.height * currentFactor,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: widget.color.withValues(
                  alpha: widget.isPlaying ? 0.85 : 0.35,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}
