import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/player_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/video_player_provider.dart';
import 'widgets/player_controls.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/lyrics_view.dart';
import 'widgets/player_shared_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/palette_provider.dart';
import '../../shared/widgets/context_menu_sheet.dart';

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight =
              constraints.maxHeight - padding.top - padding.bottom;
          final availableWidth = constraints.maxWidth;
          final isPortrait = constraints.maxHeight > constraints.maxWidth;
          final isLandscapeMobile =
              !isPortrait && availableWidth < kExpandedBreakpoint;
          final showFullscreenOverlay =
              isLandscapeMobile && activeView != PlayerSubView.none;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildPlayerBackground(artUrl, theme)),
              if (showFullscreenOverlay)
                _fullscreenOverlayLayout(
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
                )
              else if (availableWidth < kCompactBreakpoint || isPortrait)
                _mobileLayout(
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
                )
              else if (availableWidth < kExpandedBreakpoint)
                _tabletLayout(
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
                )
              else
                _wideLayout(
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
                ),
            ],
          );
        },
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
              _topBar(currentSong, isVideo, albumName),
              const SizedBox(height: 24),
              Expanded(
                child:
                    activeView == PlayerSubView.none
                        ? Center(
                          child: _artwork(
                            artUrl,
                            min(availWidth - 48, availHeight - 360),
                            isSwitching: playerState.isSwitching,
                            isVideo: isVideo,
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

  // ─── Fullscreen Overlay (landscape mobile queue/lyrics) ─────

  Widget _fullscreenOverlayLayout(
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
    final subViewNotifier = ref.read(playerSubViewProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            _topBar(
              currentSong,
              isVideo,
              albumName,
              onClose: () => subViewNotifier.set(PlayerSubView.none),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  activeView == PlayerSubView.lyrics
                      ? LyricsView(
                        videoId: videoId,
                        position: playerState.position,
                      )
                      : const QueueSheet(),
            ),
            const SizedBox(height: 12),
            _progressBar(playerState, videoId),
            const SizedBox(height: 12),
            const PlayerControls(),
            const SizedBox(height: 4),
            _bottomActionsRow(
              isVideo,
              hasSleepTimer,
              playerNotifier,
              activeView,
            ),
            const SizedBox(height: 8),
          ],
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
    final tight = availHeight < 600;
    // 2-column layout for tablet
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32.0,
          vertical: tight ? 4.0 : 16.0,
        ),
        child: Column(
          children: [
            _topBar(currentSong, isVideo, albumName),
            Expanded(
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
                          min(
                            availHeight - (tight ? 70 : 100),
                            availWidth / 2 - 48,
                          ),
                          isSwitching: playerState.isSwitching,
                          isVideo: isVideo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 1,
                    child: LayoutBuilder(
                      builder: (context, rightConstraints) {
                        final isPanelOpen = activeView != PlayerSubView.none;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:
                              isPanelOpen
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                          children: [
                            if (isPanelOpen) ...[
                              SizedBox(height: tight ? 2 : 24),
                              _trackInfoAndLikeRow(
                                currentSong,
                                isVideo,
                                albumName,
                              ),
                              SizedBox(height: tight ? 2 : 16),
                              Expanded(
                                child:
                                    activeView == PlayerSubView.lyrics
                                        ? LyricsView(
                                          videoId: videoId,
                                          position: playerState.position,
                                        )
                                        : const QueueSheet(),
                              ),
                              SizedBox(height: tight ? 2 : 16),
                              _progressBar(playerState, videoId),
                              SizedBox(height: tight ? 2 : 16),
                              const PlayerControls(),
                              SizedBox(height: tight ? 0 : 8),
                              _bottomActionsRow(
                                isVideo,
                                hasSleepTimer,
                                playerNotifier,
                                activeView,
                              ),
                              SizedBox(height: tight ? 2 : 16),
                            ] else ...[
                              _trackInfoAndLikeRow(
                                currentSong,
                                isVideo,
                                albumName,
                              ),
                              SizedBox(height: tight ? 8 : 28),
                              _progressBar(playerState, videoId),
                              SizedBox(height: tight ? 8 : 28),
                              const PlayerControls(),
                              SizedBox(height: tight ? 6 : 20),
                              _bottomActionsRow(
                                isVideo,
                                hasSleepTimer,
                                playerNotifier,
                                activeView,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
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
    final tight = availHeight < 600;
    // More spacious 2-column layout for wide
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 64.0,
          vertical: tight ? 8.0 : 32.0,
        ),
        child: Column(
          children: [
            _topBar(currentSong, isVideo, albumName),
            Expanded(
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
                          min(
                            availHeight - (tight ? 100 : 150),
                            availWidth / 2 - 100,
                          ),
                          isSwitching: playerState.isSwitching,
                          isVideo: isVideo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 80),
                  Expanded(
                    flex: 5,
                    child: LayoutBuilder(
                      builder: (context, rightConstraints) {
                        final isPanelOpen = activeView != PlayerSubView.none;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:
                              isPanelOpen
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                          children: [
                            if (isPanelOpen) ...[
                              SizedBox(height: tight ? 2 : 32),
                              _trackInfoAndLikeRow(
                                currentSong,
                                isVideo,
                                albumName,
                              ),
                              SizedBox(height: tight ? 2 : 16),
                              Expanded(
                                child:
                                    activeView == PlayerSubView.lyrics
                                        ? LyricsView(
                                          videoId: videoId,
                                          position: playerState.position,
                                        )
                                        : const QueueSheet(),
                              ),
                              SizedBox(height: tight ? 2 : 16),
                              _progressBar(playerState, videoId),
                              SizedBox(height: tight ? 2 : 24),
                              const PlayerControls(),
                              SizedBox(height: tight ? 2 : 16),
                              _bottomActionsRow(
                                isVideo,
                                hasSleepTimer,
                                playerNotifier,
                                activeView,
                              ),
                              SizedBox(height: tight ? 2 : 16),
                            ] else ...[
                              _trackInfoAndLikeRow(
                                currentSong,
                                isVideo,
                                albumName,
                              ),
                              SizedBox(height: tight ? 12 : 40),
                              _progressBar(playerState, videoId),
                              SizedBox(height: tight ? 12 : 40),
                              const PlayerControls(),
                              SizedBox(height: tight ? 8 : 32),
                              _bottomActionsRow(
                                isVideo,
                                hasSleepTimer,
                                playerNotifier,
                                activeView,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
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
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    return buildPlayerBackground(
      artUrl,
      _dominantColor,
      _isDark,
      theme.colorScheme,
      context: context,
      reduceEffects: reduceEffects,
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────

  Widget _topBar(
    MediaItem currentSong,
    bool isVideo,
    String? albumName, {
    VoidCallback? onClose,
  }) {
    final theme = Theme.of(context);
    final pc = PlayerColors.of(context);
    final videoId = currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final artistId = currentSong.extras?['artistId'] as String?;
    final albumId = currentSong.extras?['albumId'] as String?;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(LucideIcons.chevronDown, color: pc.iconPrimary),
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          tooltip: AppLocalizations.of(context)!.close,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.playingFrom,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pc.subtitle,
                  letterSpacing: 1.2,
                ),
              ),
              if (albumName != null)
                Text(
                  albumName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: pc.titlePrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  AppLocalizations.of(context)!.nowPlaying,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: pc.titlePrimary,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.moreVertical, color: pc.iconPrimary),
          onPressed: () {
            final router = GoRouter.of(context);
            ContextMenuSheet.showForNowPlaying(
              context,
              videoId: videoId,
              title: currentSong.title,
              artist: currentSong.artist ?? '',
              thumbnailUrl: currentSong.artUri?.toString(),
              albumName: albumName,
              isVideo: isVideo,
              artistId: artistId,
              albumId: albumId,
              onGoToArtist: (artistId) {
                Navigator.of(context).pop();
                router.push('/artist/$artistId');
              },
              onGoToAlbum: (albumId) {
                Navigator.of(context).pop();
                router.push('/album/$albumId');
              },
            );
          },
        ),
      ],
    );
  }

  Widget _artwork(
    String? artUrl,
    double size, {
    bool isSwitching = false,
    bool isVideo = false,
  }) {
    final videoState = ref.watch(videoPlayerProvider);
    if (isVideo && videoState.isVideoVisible && videoState.isInitialized) {
      return SonoraVideoPlayer(
        width: size,
        height: size / videoState.aspectRatio,
        borderRadius: BorderRadius.circular(12),
        tag: 'full',
      );
    }
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    return buildArtwork(
      context,
      artUrl,
      isSwitching,
      size,
      _dominantColor,
      reduceEffects: reduceEffects,
    );
  }

  Widget _trackInfoAndLikeRow(MediaItem song, bool isVideo, String? albumName) {
    return buildTrackInfoAndLikeRow(context, ref, song, isVideo);
  }

  Widget _progressBar(PlayerState playerState, String videoId) {
    return buildProgressBar(ref, playerState, videoId);
  }

  Widget _bottomActionsRow(
    bool isVideo,
    bool hasTimer,
    PlayerNotifier playerNotifier,
    PlayerSubView activeView,
  ) {
    return buildBottomActionsRow(
      context,
      ref,
      isVideo,
      hasTimer,
      playerNotifier,
      activeView,
    );
  }
}
