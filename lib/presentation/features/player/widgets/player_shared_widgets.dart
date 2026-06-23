import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:marquee/marquee.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/extensions/stat_format.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/video_player_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import 'progress_bar_widget.dart';
import 'cast_button.dart';

/// Blurred artwork + animated gradient overlay.
///
/// [dominantColor] and [isDark] come from [paletteNotifierProvider]; they
/// drive the gradient colour and opacity of Layer 2.
Widget buildPlayerBackground(
  String? artUrl,
  Color dominantColor,
  bool isDark,
  ColorScheme colorScheme, {
  BuildContext? context,
  bool reduceEffects = false,
}) {
  // Resolve PlayerColors if a context is available; fall back to standard
  // values so the function remains callable without a BuildContext (e.g. from
  // initState or static helpers).
  final pc =
      context != null
          ? PlayerColors.maybeOf(context) ?? PlayerColors.standard()
          : PlayerColors.standard();

  final gradientDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.55, 1.0],
      colors: [
        dominantColor.withValues(alpha: isDark ? 0.85 : 0.94),
        dominantColor.withValues(alpha: isDark ? 0.65 : 0.80),
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.97),
      ],
    ),
  );

  return Stack(
    fit: StackFit.expand,
    children: [
      // Layer 1 — heavily blurred artwork fills the entire background.
      if (artUrl != null && !reduceEffects)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: ImageFiltered(
            key: ValueKey(artUrl),
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: CachedNetworkImage(
              imageUrl: artUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              placeholder: (_, _) => const ColoredBox(color: Colors.black),
              errorWidget: (_, _, _) => const ColoredBox(color: Colors.black87),
            ),
          ),
        )
      else
        const ColoredBox(color: Colors.black87),

      // Layer 2 — dominant-colour gradient from top to bottom (palette-driven).
      // Alpha values tuned for readability: strong at top, progressively
      // lighter toward the bottom where a separate scrim (Layer 4) takes over.
      if (reduceEffects)
        DecoratedBox(decoration: gradientDecoration)
      else
        AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          decoration: gradientDecoration,
        ),

      // Layer 3 — bottom scrim: guarantees a dark base where queue, lyrics
      // and controls sit, regardless of dominant colour or theme brightness.
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.45, 1.0],
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.25),
              Colors.black.withValues(alpha: 0.55),
            ],
          ),
        ),
      ),

      // Layer 4 — top scrim from PlayerColors: palette-independent dark band
      // that guarantees the chevron, drag handle and "Playing from" label are
      // always readable regardless of artwork colour.
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.18, 0.28],
            colors: [pc.topScrimStart, pc.topScrimMid, Colors.transparent],
          ),
        ),
      ),
    ],
  );
}

/// Full-size artwork with dynamic box shadow driven by [dominantColor].
Widget buildArtwork(
  BuildContext context,
  String? artUrl,
  bool isSwitching,
  double size,
  Color dominantColor, {
  bool reduceEffects = false,
}) {
  final clampedSize = size.clamp(150.0, 600.0);
  Widget content;
  if (isSwitching) {
    content = const ShimmerLoading(variant: ShimmerVariant.artworkLarge);
  } else if (artUrl != null) {
    content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      layoutBuilder:
          (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
      child: CachedNetworkImage(
        key: ValueKey(artUrl),
        imageUrl: artUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder:
            (_, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
        errorWidget:
            (_, _, _) => Icon(
              LucideIcons.music,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  } else {
    content = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        LucideIcons.music,
        size: 80,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        if (!reduceEffects)
          BoxShadow(
            color: dominantColor.withValues(alpha: 0.55),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: clampedSize, height: clampedSize, child: content),
    ),
  );
}

/// Like-button with animated scale+fade transition.
Widget buildLikeButton(BuildContext context, WidgetRef ref, MediaItem song) {
  final videoId = song.extras?['videoId'] as String? ?? song.id;
  final title = song.title;
  final artist = song.artist ?? AppLocalizations.of(context)!.unknownArtist;
  final thumbnailUrl = song.artUri?.toString();

  final likedAsync = ref.watch(likedSongProvider(videoId));
  return likedAsync.when(
    loading: () => const Icon(LucideIcons.heart, size: 28),
    error: (_, _) => const Icon(LucideIcons.heart, size: 28),
    data: (liked) {
      final isLiked = liked != null;
      return IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder:
              (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
          child: Icon(
            LucideIcons.heart,
            key: ValueKey(isLiked),
            size: 28,
            color: isLiked ? Theme.of(context).colorScheme.error : null,
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          ref
              .read(libraryNotifierProvider.notifier)
              .toggleLikedSong(
                LikedSongModel(
                  videoId: videoId,
                  title: title,
                  artist: artist,
                  thumbnailUrl: thumbnailUrl,
                  addedAt: DateTime.now(),
                  isVideo: song.extras?['isVideo'] == true,
                ),
              );
        },
      );
    },
  );
}

/// Track title (with optional marquee), artist, MV badge and view-count stats.
Widget buildTrackInfoAndLikeRow(
  BuildContext context,
  WidgetRef ref,
  MediaItem song,
  bool isVideo,
) {
  final theme = Theme.of(context);
  final viewCount = song.extras?['viewCount'] as int?;
  final publishDate = song.extras?['publishDate'] as String?;
  final statParts = <String>[];
  if (viewCount != null) {
    statParts.add(
      '${viewCount.toCompact()} ${AppLocalizations.of(context)!.views}',
    );
  }
  if (publishDate != null && publishDate.isNotEmpty) {
    statParts.add(publishDate);
  }

  // Colours from PlayerColors — always readable on the dark player background.
  final pc = PlayerColors.of(context);

  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final titleStyle = theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: pc.titlePrimary,
                      );
                      final tp = TextPainter(
                        text: TextSpan(text: song.title, style: titleStyle),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: double.infinity);
                      if (tp.width > constraints.maxWidth) {
                        return SizedBox(
                          height: 32,
                          child: Marquee(
                            text: song.title,
                            style: titleStyle,
                            blankSpace: 48.0,
                            velocity: 40.0,
                            pauseAfterRound: const Duration(seconds: 2),
                            fadingEdgeStartFraction: 0.05,
                            fadingEdgeEndFraction: 0.1,
                          ),
                        );
                      }
                      return Text(
                        song.title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                if (isVideo) ...[
                  const SizedBox(width: 8),
                  buildMvBadge(context),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              song.artist ?? '',
              style: theme.textTheme.titleMedium?.copyWith(color: pc.subtitle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (statParts.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                statParts.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pc.labelMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 16),
      buildLikeButton(context, ref, song),
    ],
  );
}

/// Tiny "MV" badge for video content.
Widget buildMvBadge(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: cs.tertiary.withValues(alpha: 0.15),
      border: Border.all(color: cs.tertiary.withValues(alpha: 0.3), width: 1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      AppLocalizations.of(context)!.mv,
      style: theme.textTheme.labelSmall?.copyWith(
        color: cs.tertiary,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

/// Thin wrapper around [ProgressBarWidget].
Widget buildProgressBar(
  WidgetRef ref,
  PlayerState playerState,
  String videoId,
) {
  return ProgressBarWidget(
    position: playerState.position,
    duration: playerState.duration,
    seed: videoId.hashCode,
    disabled: playerState.isRestoring,
    onSeek: (pos) => ref.read(playerStateProvider.notifier).seek(pos),
  );
}

/// Row of actions: share, cast, lyrics toggle, queue toggle, sleep timer.
Widget buildBottomActionsRow(
  BuildContext context,
  WidgetRef ref,
  bool isVideo,
  bool hasTimer,
  PlayerNotifier playerNotifier,
  PlayerSubView activeView, {
  bool isMobile = false,
}) {
  final theme = Theme.of(context);
  return Row(
    mainAxisAlignment:
        isMobile ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
    children: [
      IconButton(
        icon: const Icon(LucideIcons.share2),
        onPressed: () {
          final currentSong = ref.read(playerStateProvider).currentSong;
          final vId =
              currentSong?.extras?['videoId'] as String? ?? currentSong?.id;
          if (vId != null) {
            SharePlus.instance.share(
              ShareParams(text: 'https://music.youtube.com/watch?v=$vId'),
            );
          }
        },
        tooltip: AppLocalizations.of(context)!.share,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      CastButton(size: 22, color: theme.colorScheme.onSurfaceVariant),
      if (isVideo) ...[
        Builder(
          builder: (context) {
            final videoState = ref.watch(videoPlayerProvider);
            return IconButton(
              icon: Icon(
                videoState.isVideoVisible
                    ? LucideIcons.monitor
                    : LucideIcons.monitorOff,
                color:
                    videoState.isVideoVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                ref.read(videoPlayerProvider.notifier).toggleVisibility();
              },
              tooltip: videoState.isVideoVisible ? 'Hide video' : 'Show video',
            );
          },
        ),
      ],
      if (!isVideo)
        IconButton(
          icon: Icon(
            LucideIcons.micVocal,
            color:
                activeView == PlayerSubView.lyrics
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            ref
                .read(playerSubViewProvider.notifier)
                .set(
                  activeView == PlayerSubView.lyrics
                      ? PlayerSubView.none
                      : PlayerSubView.lyrics,
                );
          },
          tooltip: AppLocalizations.of(context)!.lyrics,
        ),
      IconButton(
        icon: Icon(
          LucideIcons.listMusic,
          color:
              activeView == PlayerSubView.queue
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          ref
              .read(playerSubViewProvider.notifier)
              .set(
                activeView == PlayerSubView.queue
                    ? PlayerSubView.none
                    : PlayerSubView.queue,
              );
        },
        tooltip: AppLocalizations.of(context)!.queue,
      ),
      IconButton(
        icon: Icon(
          LucideIcons.timer,
          size: 22,
          color:
              hasTimer
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: () => showPlayerTimerDialog(context, playerNotifier),
        tooltip:
            hasTimer
                ? AppLocalizations.of(context)!.sleepTimerActive
                : AppLocalizations.of(context)!.sleepTimer,
      ),
    ],
  );
}

/// Modal bottom sheet with sleep timer options.
void showPlayerTimerDialog(BuildContext context, PlayerNotifier notifier) {
  final options = [5, 10, 15, 30, 45, 60];
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.sleepTimer,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...options.map(
                (minutes) => ListTile(
                  title: Text(
                    minutes >= 60
                        ? '${minutes ~/ 60} hour'
                        : '$minutes minutes',
                  ),
                  onTap: () {
                    notifier.setSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(ctx);
                  },
                ),
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.timerOff,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(context)!.cancelTimer,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  notifier.cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
