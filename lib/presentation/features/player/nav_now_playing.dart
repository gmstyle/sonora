import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../../shared/widgets/vinyl_artwork.dart';
import 'full_player_content.dart';
import 'widgets/progress_bar_widget.dart';

/// Now-playing chrome that lives with vertical navigation.
///
/// Compact (tablet rail / collapsed sidebar): progress-ring disc.
/// Expanded (wide sidebar): artwork, title, and a display-only progress wave.
/// Transport always lives in the mini player, never here.
class NavNowPlaying extends ConsumerWidget {
  final bool expanded;

  const NavNowPlaying({super.key, required this.expanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child:
          expanded
              ? _ExpandedCard(playerState: playerState)
              : _CompactDisc(playerState: playerState),
    );
  }
}

class _CompactDisc extends ConsumerWidget {
  final PlayerState playerState;

  const _CompactDisc({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = playerState.currentSong!;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final totalMs = playerState.duration.inMilliseconds;
    final progress =
        totalMs > 0 ? playerState.position.inMilliseconds / totalMs : 0.0;
    final tooltip = '${song.title} — ${song.artist ?? l10n.unknownArtist}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () => openFullPlayer(context),
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: cs.outlineVariant.withValues(alpha: 0.45),
              progressColor: cs.primary,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _Artwork(
                imageUrl: song.artUri?.toString(),
                size: 44,
                isPlaying: playerState.isPlaying,
                compact: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedCard extends ConsumerWidget {
  final PlayerState playerState;

  const _ExpandedCard({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = playerState.currentSong!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Material(
        color: cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openFullPlayer(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Artwork(
                  imageUrl: song.artUri?.toString(),
                  size: 80,
                  isPlaying: playerState.isPlaying,
                  compact: false,
                  tooltip: l10n.openPlayer,
                ),
                const SizedBox(height: 10),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist ?? l10n.unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                ProgressBarWidget(
                  position: playerState.position,
                  duration: playerState.duration,
                  disabled: true,
                  isPlaying: playerState.isPlaying,
                  isMini: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends ConsumerWidget {
  final String? imageUrl;
  final double size;
  final bool isPlaying;
  final bool compact;
  final String? tooltip;

  const _Artwork({
    required this.imageUrl,
    required this.size,
    required this.isPlaying,
    required this.compact,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useVinyl = ref.watch(settingsProvider.select((s) => s.useVinylStyle));
    if (useVinyl) {
      return VinylArtwork(
        imageUrl: imageUrl,
        size: size,
        isPlaying: isPlaying,
        useShadow: false,
        tooltipMessage: tooltip,
      );
    }
    return ThumbnailWidget(
      imageUrl: imageUrl,
      size: size,
      shape: compact ? ThumbnailShape.circle : ThumbnailShape.rounded,
      borderRadius: compact ? null : 12,
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor;
  }
}
