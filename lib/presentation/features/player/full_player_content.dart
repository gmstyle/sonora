import 'dart:math';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../domain/models/library_models.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import 'widgets/player_controls.dart';
import 'widgets/progress_bar_widget.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/lyrics_view.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:marquee/marquee.dart';
import '../../providers/palette_provider.dart';

class FullPlayerContent extends ConsumerStatefulWidget {
  final PlayerSubView initialSubView;

  const FullPlayerContent({
    super.key,
    this.initialSubView = PlayerSubView.none,
  });

  @override
  ConsumerState<FullPlayerContent> createState() => _FullPlayerContentState();
}

class _FullPlayerContentState extends ConsumerState<FullPlayerContent> {
  Color _dominantColor = Colors.black87;
  bool _isDark = true;
  late final PlayerSubViewNotifier _subViewNotifier;

  @override
  void initState() {
    super.initState();
    _subViewNotifier = ref.read(playerSubViewProvider.notifier);
    if (widget.initialSubView != PlayerSubView.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _subViewNotifier.set(widget.initialSubView);
      });
    }
  }

  @override
  void dispose() {
    Future.microtask(() => _subViewNotifier.set(PlayerSubView.none));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final activeView = ref.watch(playerSubViewProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final isVideo = currentSong.extras?['isVideo'] == true;
    final videoId = currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final artUrl = currentSong.artUri?.toString();
    final albumName = currentSong.album;
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewPadding;
    final hasSleepTimer = playerState.sleepTimerRemaining != null;

    // ── Palette ───────────────────────────────────────────────────
    // Read cached palette for the current song. If not yet extracted,
    // schedule extraction after this frame (safe: PaletteNotifier guards
    // against duplicate work with containsKey).
    final paletteMap = ref.watch(paletteNotifierProvider);
    final paletteData = paletteMap[videoId];
    _dominantColor =
        paletteData?.dominantColor ?? theme.colorScheme.primaryContainer;
    _isDark = paletteData?.isDark ?? true;
    if (paletteData == null && artUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(paletteNotifierProvider.notifier)
              .extractPalette(videoId, artUrl);
        }
      });
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1 — blurred artwork + animated gradient overlay.
          Positioned.fill(child: _buildPlayerBackground(artUrl, theme)),
          // Layer 2 — content (layouts are transparent over the background).
          LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight =
                  constraints.maxHeight - padding.top - padding.bottom;
              final availableWidth = constraints.maxWidth;

              if (constraints.maxWidth < kCompactBreakpoint) {
                return _mobileLayout(
                  theme,
                  currentSong,
                  isVideo,
                  videoId,
                  artUrl,
                  albumName,
                  playerState,
                  playerNotifier,
                  hasSleepTimer,
                  availableHeight,
                  availableWidth,
                  padding.bottom,
                  activeView,
                );
              } else if (constraints.maxWidth < kExpandedBreakpoint) {
                return _tabletLayout(
                  theme,
                  currentSong,
                  isVideo,
                  videoId,
                  artUrl,
                  albumName,
                  playerState,
                  playerNotifier,
                  hasSleepTimer,
                  availableHeight,
                  availableWidth,
                  padding.bottom,
                  activeView,
                );
              } else {
                return _wideLayout(
                  theme,
                  currentSong,
                  isVideo,
                  videoId,
                  artUrl,
                  albumName,
                  playerState,
                  playerNotifier,
                  hasSleepTimer,
                  availableHeight,
                  availableWidth,
                  padding.bottom,
                  activeView,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────

  Widget _mobileLayout(
    ThemeData theme,
    MediaItem currentSong,
    bool isVideo,
    String videoId,
    String? artUrl,
    String? albumName,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
    bool hasSleepTimer,
    double availHeight,
    double availWidth,
    double bottomInset,
    PlayerSubView activeView,
  ) {
    return SafeArea(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Drag handle — visual affordance for the swipe-down gesture.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _topBar(albumName),
              const SizedBox(height: 24),
              Expanded(
                child:
                    activeView == PlayerSubView.none
                        ? Center(
                          child: _artwork(
                            artUrl,
                            availWidth - 48,
                            isSwitching: playerState.isSwitching,
                          ),
                        )
                        : activeView == PlayerSubView.lyrics
                        ? LyricsView(
                          videoId: videoId,
                          position: playerState.position,
                        )
                        : const QueueSheet(),
              ),
              const SizedBox(height: 32),
              _trackInfoAndLikeRow(currentSong, isVideo, albumName),
              const SizedBox(height: 16),
              _progressBar(playerState, videoId),
              const SizedBox(height: 16),
              const PlayerControls(),
              const SizedBox(height: 8),
              _bottomActionsRow(
                isVideo,
                playerState.sleepTimerRemaining != null,
                playerNotifier,
                activeView,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tablet ───────────────────────────────────────────────────

  Widget _tabletLayout(
    ThemeData theme,
    MediaItem currentSong,
    bool isVideo,
    String videoId,
    String? artUrl,
    String? albumName,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
    bool hasSleepTimer,
    double availHeight,
    double availWidth,
    double bottomInset,
    PlayerSubView activeView,
  ) {
    // 2-column layout for tablet
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _artwork(
                    artUrl,
                    min(availHeight - 100, availWidth / 2 - 48),
                    isSwitching: playerState.isSwitching,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(albumName),
                  const SizedBox(height: 24),
                  _trackInfoAndLikeRow(currentSong, isVideo, albumName),
                  const SizedBox(height: 16),
                  if (activeView != PlayerSubView.none)
                    Expanded(
                      child:
                          activeView == PlayerSubView.lyrics
                              ? LyricsView(
                                videoId: videoId,
                                position: playerState.position,
                              )
                              : const QueueSheet(),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 16),
                  _progressBar(playerState, videoId),
                  const SizedBox(height: 16),
                  const PlayerControls(),
                  const SizedBox(height: 8),
                  _bottomActionsRow(
                    isVideo,
                    hasSleepTimer,
                    playerNotifier,
                    activeView,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Wide ─────────────────────────────────────────────────────

  Widget _wideLayout(
    ThemeData theme,
    MediaItem currentSong,
    bool isVideo,
    String videoId,
    String? artUrl,
    String? albumName,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
    bool hasSleepTimer,
    double availHeight,
    double availWidth,
    double bottomInset,
    PlayerSubView activeView,
  ) {
    // More spacious 2-column layout for wide
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _artwork(
                    artUrl,
                    min(availHeight - 150, availWidth / 2 - 100),
                    isSwitching: playerState.isSwitching,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 80),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(albumName),
                  const SizedBox(height: 32),
                  _trackInfoAndLikeRow(currentSong, isVideo, albumName),
                  const SizedBox(height: 16),
                  if (activeView != PlayerSubView.none)
                    Expanded(
                      child:
                          activeView == PlayerSubView.lyrics
                              ? LyricsView(
                                videoId: videoId,
                                position: playerState.position,
                              )
                              : const QueueSheet(),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 16),
                  _progressBar(playerState, videoId),
                  const SizedBox(height: 24),
                  const PlayerControls(),
                  const SizedBox(height: 16),
                  _bottomActionsRow(
                    isVideo,
                    hasSleepTimer,
                    playerNotifier,
                    activeView,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Background ──────────────────────────────────────────────

  /// Two-layer background: blurred artwork image (Layer 1) covered by an
  /// animated gradient overlay driven by [_dominantColor] (Layer 2).
  /// The gradient fades from the dominant color (top) to the theme surface
  /// color (bottom) to keep text and controls always readable.
  Widget _buildPlayerBackground(String? artUrl, ThemeData theme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: artwork blurred to ∞ — acts as a "coloured wallpaper".
        if (artUrl != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: ImageFiltered(
              key: ValueKey(artUrl),
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: CachedNetworkImage(
                imageUrl: artUrl,
                fit: BoxFit.cover,
                // Scale up slightly so blur doesn't show transparent edges.
                alignment: Alignment.center,
                placeholder: (_, _) => const ColoredBox(color: Colors.black),
                errorWidget:
                    (_, _, _) => const ColoredBox(color: Colors.black87),
              ),
            ),
          )
        else
          const ColoredBox(color: Colors.black87),
        // Layer 2: animated colour wash — transitions smoothly when song changes.
        // When the dominant colour is light (_isDark == false), we increase the
        // overlay alpha to preserve text readability (contrast adaptation).
        AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
              colors: [
                _dominantColor.withValues(alpha: _isDark ? 0.72 : 0.85),
                _dominantColor.withValues(alpha: _isDark ? 0.45 : 0.62),
                theme.colorScheme.surface.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────

  Widget _topBar(String? albumName) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.chevronDown),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: AppLocalizations.of(context)!.close,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.playingFrom,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              if (albumName != null)
                Text(
                  albumName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  AppLocalizations.of(context)!.nowPlaying,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        /*
        TODO: Add context menu for album/artist actions (e.g. view album, view artist)
        IconButton(
          icon: const Icon(LucideIcons.moreVertical),
          onPressed: () {
            // Context menu logic
          },
        ), */
      ],
    );
  }

  Widget _artwork(String? artUrl, double size, {bool isSwitching = false}) {
    final clampedSize = size.clamp(150.0, 600.0);
    Widget content;
    if (isSwitching) {
      content = const ShimmerLoading(variant: ShimmerVariant.artworkLarge);
    } else if (artUrl != null) {
      // AnimatedSwitcher crossfades to the new artwork when the song changes.
      // Custom layoutBuilder with StackFit.expand ensures the crossfade Stack
      // fills the SizedBox rather than shrinking to the image's natural size.
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
    // Dynamic glow shadow: colour and intensity driven by the dominant palette
    // colour of the current artwork instead of the fixed black shadow.
    return Hero(
      tag: 'player_art',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _dominantColor.withValues(alpha: 0.55),
              blurRadius: 32,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: clampedSize,
            height: clampedSize,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _trackInfoAndLikeRow(MediaItem song, bool isVideo, String? albumName) {
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
                        );
                        // Measure natural text width at single line.
                        final tp = TextPainter(
                          text: TextSpan(text: song.title, style: titleStyle),
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: double.infinity);
                        // Only activate Marquee when the title overflows.
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.3,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.mv,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                song.artist ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (statParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  statParts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        _likeButton(song),
      ],
    );
  }

  Widget _progressBar(PlayerState playerState, String videoId) {
    return ProgressBarWidget(
      position: playerState.position,
      duration: playerState.duration,
      seed: videoId.hashCode,
      onSeek: (pos) => ref.read(playerStateProvider.notifier).seek(pos),
    );
  }

  Widget _likeButton(MediaItem song) {
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
                  ),
                );
          },
        );
      },
    );
  }

  Widget _bottomActionsRow(
    bool isVideo,
    bool hasTimer,
    PlayerNotifier playerNotifier,
    PlayerSubView activeView,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        /*
        TODO: Add device output selection (e.g. Chromecast, Bluetooth)
        IconButton(
          icon: const Icon(LucideIcons.speaker),
          onPressed: () {},
          tooltip: AppLocalizations.of(context)!.devices,
          color: theme.colorScheme.onSurfaceVariant,
        ), */
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.share2),
              onPressed: () {
                final currentSong = ref.read(playerStateProvider).currentSong;
                final vId =
                    currentSong?.extras?['videoId'] as String? ??
                    currentSong?.id;
                if (vId != null) {
                  SharePlus.instance.share(
                    ShareParams(text: 'https://music.youtube.com/watch?v=$vId'),
                  );
                }
              },
              tooltip: AppLocalizations.of(context)!.share,
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
              onPressed: () => _showTimerDialog(context, playerNotifier),
              tooltip:
                  hasTimer
                      ? AppLocalizations.of(context)!.sleepTimerActive
                      : AppLocalizations.of(context)!.sleepTimer,
            ),
          ],
        ),
      ],
    );
  }

  void _showTimerDialog(BuildContext context, PlayerNotifier notifier) {
    final options = [5, 10, 15, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.sleepTimer,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
        );
      },
    );
  }
}
