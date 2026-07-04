import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/video_badge.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import 'widgets/animated_play_pause_icon.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/cast_button.dart';
import '../../../core/extensions/duration_ext.dart';

class MiniPlayerContent extends ConsumerWidget {
  final MediaItem currentSong;
  final PlayerState playerState;
  final bool isVideo;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenQueue;

  const MiniPlayerContent({
    super.key,
    required this.currentSong,
    required this.playerState,
    required this.isVideo,
    this.onTap,
    this.onPlayPause,
    this.onSkipNext,
    this.onSkipPrevious,
    this.onOpenLyrics,
    this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSwitching = playerState.isBlocked;
    final progress =
        playerState.duration.inMilliseconds > 0
            ? playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds
            : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _mobileLayout(context, ref, isSwitching, progress);
        } else if (constraints.maxWidth < 1200) {
          return _tabletLayout(context, ref, isSwitching, progress);
        } else {
          return _desktopLayout(context, ref, isSwitching, progress);
        }
      },
    );
  }

  // ── Mobile Layout (<600px) ──────────────────────────────────────

  Widget _mobileLayout(
    BuildContext context,
    WidgetRef ref,
    bool isSwitching,
    double progress,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: isSwitching ? null : onTap,
      onHorizontalDragEnd: (details) {
        if (isSwitching) return;
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -250) {
          HapticFeedback.lightImpact();
          onSkipNext?.call();
        } else if (details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          onSkipPrevious?.call();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSwitching)
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          _glassBar(
            cs: cs,
            ref: ref,
            child:
                isSwitching
                    ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                    : Row(
                      children: [
                        const SizedBox(width: 12),
                        _artwork(size: 56, radius: 8, cs: cs, ref: ref),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentSong.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (currentSong.extras?['isExplicit'] == true)
                                    const ExplicitBadge(
                                      leading: SizedBox(width: 6),
                                    ),
                                  if (isVideo)
                                    const VideoBadge(
                                      leading: SizedBox(width: 6),
                                    ),
                                ],
                              ),
                              Text(
                                currentSong.artist ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        _playPauseButton(cs),
                        _iconButton(
                          icon: LucideIcons.skipForward,
                          color: cs.onSurfaceVariant,
                          onPressed: onSkipNext,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ── Tablet Layout (600–1199px) ──────────────────────────────────

  Widget _tabletLayout(
    BuildContext context,
    WidgetRef ref,
    bool isSwitching,
    double progress,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: isSwitching ? null : onTap,
      onHorizontalDragEnd: (details) {
        if (isSwitching) return;
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -250) {
          HapticFeedback.lightImpact();
          onSkipNext?.call();
        } else if (details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          onSkipPrevious?.call();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSwitching)
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          _glassBar(
            cs: cs,
            ref: ref,
            child:
                isSwitching
                    ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                    : Row(
                      children: [
                        const SizedBox(width: 12),
                        _artwork(size: 60, radius: 8, cs: cs, ref: ref),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentSong.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (currentSong.extras?['isExplicit'] == true)
                                    const ExplicitBadge(
                                      leading: SizedBox(width: 6),
                                    ),
                                  if (isVideo)
                                    const VideoBadge(
                                      leading: SizedBox(width: 6),
                                    ),
                                ],
                              ),
                              Text(
                                currentSong.artist ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        _iconButton(
                          icon: LucideIcons.skipBack,
                          color: cs.onSurfaceVariant,
                          onPressed: onSkipPrevious,
                          size: 20,
                        ),
                        _playPauseButton(cs),
                        _iconButton(
                          icon: LucideIcons.skipForward,
                          color: cs.onSurfaceVariant,
                          onPressed: onSkipNext,
                          size: 20,
                        ),
                        _likeButton(context, ref, cs),
                        CastButton(size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ── Desktop Layout (≥1200px) ────────────────────────────────────

  Widget _desktopLayout(
    BuildContext context,
    WidgetRef ref,
    bool isSwitching,
    double progress,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeView = ref.watch(playerSubViewProvider);
    final elapsed = _formatDuration(playerState.position);
    final remaining =
        playerState.duration > playerState.position
            ? '-${_formatDuration(playerState.duration - playerState.position)}'
            : '-0:00';

    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width >= kExpandedBreakpoint;
    final isSidebarExpanded =
        isWideScreen && !ref.watch(sidebarCollapsedProvider);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (isSwitching) return;
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -250) {
          HapticFeedback.lightImpact();
          onSkipNext?.call();
        } else if (details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          onSkipPrevious?.call();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _glassBar(
            cs: cs,
            ref: ref,
            child:
                isSwitching
                    ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                    : Row(
                      children: [
                        // LEFT — artwork + title/artist (tap to open full player)
                        if (isSidebarExpanded)
                          const Spacer(flex: 3)
                        else
                          Expanded(
                            flex: 3,
                            child: GestureDetector(
                              onTap: isSwitching ? null : onTap,
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  _artwork(
                                    size: 56,
                                    radius: 8,
                                    cs: cs,
                                    ref: ref,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                currentSong.title,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                maxLines: 1,
                                              ),
                                            ),
                                            if (currentSong
                                                    .extras?['isExplicit'] ==
                                                true)
                                              const ExplicitBadge(
                                                leading: SizedBox(width: 6),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          currentSong.artist ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // CENTER — controls + progress + time
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _iconButton(
                                    icon: LucideIcons.skipBack,
                                    color: cs.onSurfaceVariant,
                                    onPressed: onSkipPrevious,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  _playPauseButton(cs),
                                  const SizedBox(width: 8),
                                  _iconButton(
                                    icon: LucideIcons.skipForward,
                                    color: cs.onSurfaceVariant,
                                    onPressed: onSkipNext,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Text(
                                    elapsed,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      minHeight: 2,
                                      backgroundColor:
                                          cs.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        cs.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    remaining,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // RIGHT — full - like + lyrics + queue + more
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _iconButton(
                                icon: LucideIcons.maximize2,
                                color: cs.onSurfaceVariant,
                                onPressed: isSwitching ? null : onTap,
                              ),
                              _likeButton(context, ref, cs),
                              _iconButton(
                                icon: LucideIcons.micVocal,
                                color:
                                    activeView == PlayerSubView.lyrics
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                onPressed: onOpenLyrics,
                                size: 20,
                              ),
                              _iconButton(
                                icon: LucideIcons.listMusic,
                                color:
                                    activeView == PlayerSubView.queue
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                onPressed: onOpenQueue,
                                size: 20,
                              ),
                              CastButton(size: 20, color: cs.onSurfaceVariant),
                              _iconButton(
                                icon: LucideIcons.moreVertical,
                                color: cs.onSurfaceVariant,
                                onPressed: () {
                                  final videoId =
                                      currentSong.extras?['videoId']
                                          as String? ??
                                      currentSong.id;
                                  ContextMenuSheet.showForSong(
                                    context,
                                    videoId: videoId,
                                    title: currentSong.title,
                                    artist: currentSong.artist ?? '',
                                    artistId:
                                        currentSong.extras?['artistId']
                                            as String?,
                                    albumId:
                                        currentSong.extras?['albumId']
                                            as String?,
                                    thumbnailUrl:
                                        currentSong.artUri?.toString(),
                                    duration: currentSong.duration?.inSeconds,
                                    albumName: currentSong.album,
                                    isVideo: isVideo,
                                    isExplicit:
                                        currentSong.extras?['isExplicit'] ==
                                        true,
                                  );
                                },
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────────

  /// 72 px semi-transparent bar — the blur is applied by the parent wrapper
  /// ([PlayerSheet] on tablet/wide, [PlayerSheetMobile] on mobile) so it is
  /// not duplicated here.  This widget provides only the colour + border.
  Widget _glassBar({
    required ColorScheme cs,
    required Widget child,
    required WidgetRef ref,
  }) {
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color:
            reduceEffects
                ? cs.surfaceContainerHigh
                : cs.surfaceContainerHigh.withValues(alpha: 0.82),
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _artwork({
    required double size,
    required double radius,
    required ColorScheme cs,
    required WidgetRef ref,
  }) {
    final videoState = ref.watch(videoPlayerProvider);
    if (isVideo && videoState.isVideoVisible && videoState.isInitialized) {
      return SonoraVideoPlayer(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(radius),
        fit: BoxFit.cover,
        showControls: false,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child:
            currentSong.artUri != null
                ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: CachedNetworkImage(
                    key: ValueKey(currentSong.artUri!.toString()),
                    imageUrl: currentSong.artUri!.toString(),
                    fit: BoxFit.cover,
                    placeholder:
                        (_, _) => Container(color: cs.surfaceContainerHighest),
                    errorWidget:
                        (_, _, _) =>
                            Icon(LucideIcons.music, color: cs.onSurfaceVariant),
                  ),
                )
                : Icon(LucideIcons.music, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _playPauseButton(ColorScheme cs) {
    final blocked = playerState.isBlocked;
    return IconButton(
      icon: AnimatedPlayPauseIcon(
        isPlaying: playerState.isPlaying,
        isLoading: playerState.isRestoring,
        color: cs.onPrimary,
        size: 24,
      ),
      onPressed:
          blocked
              ? null
              : () {
                HapticFeedback.lightImpact();
                onPlayPause?.call();
              },
      style: IconButton.styleFrom(
        backgroundColor: blocked ? cs.primary.withAlpha(128) : cs.primary,
        foregroundColor: cs.onPrimary,
        fixedSize: const Size(40, 40),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    double size = 20,
    bool haptic = false,
  }) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: color,
      onPressed:
          onPressed != null && haptic
              ? () {
                HapticFeedback.lightImpact();
                onPressed();
              }
              : onPressed,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }

  Widget _likeButton(BuildContext context, WidgetRef ref, ColorScheme cs) {
    final videoId = currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final title = currentSong.title;
    final artist =
        currentSong.artist ?? AppLocalizations.of(context)!.unknownArtist;
    final thumbnailUrl = currentSong.artUri?.toString();

    final likedAsync = ref.watch(likedSongProvider(videoId));
    return likedAsync.when(
      loading:
          () => _iconButton(
            icon: LucideIcons.heart,
            color: cs.onSurfaceVariant,
            onPressed: null,
            size: 20,
          ),
      error:
          (_, _) => _iconButton(
            icon: LucideIcons.heart,
            color: cs.onSurfaceVariant,
            onPressed: null,
            size: 20,
          ),
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
              color: isLiked ? cs.error : cs.onSurfaceVariant,
              size: 20,
            ),
          ),
          color: isLiked ? cs.error : cs.onSurfaceVariant,
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
                    duration: currentSong.duration?.inSeconds,
                    isVideo: currentSong.extras?['isVideo'] == true,
                    isExplicit: currentSong.extras?['isExplicit'] == true,
                  ),
                );
          },
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          splashRadius: 18,
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    return d.format();
  }
}
