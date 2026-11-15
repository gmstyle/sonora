import 'dart:math' as math;
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/screen_keep_awake.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/start_radio_use_case_provider.dart';
import '../../../shared/widgets/context_menu/context_menu_presenter.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../player/widgets/lyrics_view.dart'
    show lyricsProvider, plainLyricsProvider;
import '../tv_metrics.dart';
import '../widgets/tv_focusable.dart';

enum _TvNpViewMode { artwork, lyrics }

/// Opens the TV full-bleed now playing stage (not a go_router route).
void openTvNowPlaying(BuildContext context, {bool lyrics = false}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          TvNowPlayingScreen(showLyrics: lyrics),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      fullscreenDialog: true,
    ),
  );
}

/// Standalone Full-Screen 10-Foot Now Playing Stage for Android TV.
///
/// Features:
/// - Full-bleed 16:9 canvas with dynamic ambient backdrop derived from album art.
/// - Seamless toggle between Cinematic Artwork view and Full-Screen Karaoke Lyrics.
/// - Slide-in "Up Next" Queue Drawer overlay.
/// - Direct D-Pad navigation with high-contrast Pulse focus rings and large remote controls.
class TvNowPlayingScreen extends ConsumerStatefulWidget {
  final bool showLyrics;

  const TvNowPlayingScreen({super.key, this.showLyrics = false});

  @override
  ConsumerState<TvNowPlayingScreen> createState() => _TvNowPlayingScreenState();
}

class _TvNowPlayingScreenState extends ConsumerState<TvNowPlayingScreen> {
  late _TvNpViewMode _viewMode;
  bool _showQueue = false;
  final FocusNode _artPlayFocus = FocusNode(debugLabel: 'tvNpArtPlay');
  final FocusNode _lyricsPlayFocus = FocusNode(debugLabel: 'tvNpLyricsPlay');

  @override
  void initState() {
    super.initState();
    _viewMode = widget.showLyrics
        ? _TvNpViewMode.lyrics
        : _TvNpViewMode.artwork;
    ScreenKeepAwake.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusActiveStage());
  }

  @override
  void dispose() {
    _artPlayFocus.dispose();
    _lyricsPlayFocus.dispose();
    ScreenKeepAwake.disable();
    super.dispose();
  }

  void _focusActiveStage() {
    if (!mounted || _showQueue) return;
    final target = _viewMode == _TvNpViewMode.artwork
        ? _artPlayFocus
        : _lyricsPlayFocus;
    if (target.canRequestFocus) {
      target.requestFocus();
    }
  }

  void _setViewMode(_TvNpViewMode mode) {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusActiveStage());
  }

  void _toggleQueue() {
    final closing = _showQueue;
    setState(() => _showQueue = !_showQueue);
    if (closing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusActiveStage());
    }
  }

  void _closeQueue() {
    if (!_showQueue) return;
    setState(() => _showQueue = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusActiveStage());
  }

  KeyEventResult _handleGlobalKeys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      if (_showQueue) {
        _closeQueue();
        return KeyEventResult.handled;
      }
      if (_viewMode == _TvNpViewMode.lyrics) {
        _setViewMode(_TvNpViewMode.artwork);
        return KeyEventResult.handled;
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
      ref.read(playerStateProvider.notifier).skipToNext();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
      ref.read(playerStateProvider.notifier).skipToPrevious();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
      ref.read(playerStateProvider.notifier).togglePlayPause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final song = player.currentSong;
    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final track = QueueTrack.fromMediaItem(song);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(playerStateProvider.notifier);
    final liked = ref.watch(likedSongProvider(track.videoId)).asData?.value;
    final offline = ref.watch(isOfflineProvider);
    final shuffled = player.shuffleMode == AudioServiceShuffleMode.all;
    final artUrl = song.artUri?.toString();

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleGlobalKeys,
      child: Scaffold(
        backgroundColor: TvColors.bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Dynamic Ambient Blurred Backdrop Aura
            if (artUrl != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                  child: Opacity(
                    opacity: 0.40,
                    child: Transform.scale(
                      scale: 1.3,
                      child: ThumbnailWidget(
                        imageUrl: artUrl,
                        size: 960,
                        shape: ThumbnailShape.square,
                        borderRadius: 0,
                      ),
                    ),
                  ),
                ),
              ),

            // 2. Deep Vignette Scrim (Bottom & Center Contrast Protection)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.40),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Main Stage Content
            ExcludeFocus(
              excluding: _showQueue,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TvMetrics.overscanHorizontal,
                    TvMetrics.overscanVertical,
                    TvMetrics.overscanHorizontal,
                    TvMetrics.overscanVertical,
                  ),
                  child: Column(
                    children: [
                      // Top Bar: Back, Stage Mode Toggles, Specs
                      _TvNowPlayingTopBar(
                        viewMode: _viewMode,
                        showQueue: _showQueue,
                        queueCount: player.queue.length,
                        badgeLabel: track.isVideo
                            ? l10n.mv
                            : (track.isEpisode
                                  ? l10n.episode
                                  : l10n.nowPlaying),
                        onBack: () => Navigator.of(context).maybePop(),
                        onSelectMode: _setViewMode,
                        onToggleQueue: _toggleQueue,
                      ),

                      const SizedBox(height: 12),

                      // Main View Switcher: Artwork Cinematic Stage vs Full-Screen Lyrics
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          child: _viewMode == _TvNpViewMode.artwork
                              ? _TvArtworkCinematicStage(
                                  song: song,
                                  track: track,
                                  player: player,
                                  notifier: notifier,
                                  playFocusNode: _artPlayFocus,
                                  liked: liked != null,
                                  shuffled: shuffled,
                                  onLike: () {
                                    ref
                                        .read(libraryNotifierProvider.notifier)
                                        .toggleLikedSong(
                                          LikedSongModel(
                                            videoId: track.videoId,
                                            title: song.title,
                                            artist: song.artist ?? '',
                                            artistsJson: track.artistsJson,
                                            thumbnailUrl: artUrl,
                                            addedAt: DateTime.now(),
                                            duration: song.duration?.inSeconds,
                                            isVideo: track.isVideo,
                                            isExplicit: track.isExplicit,
                                          ),
                                        );
                                  },
                                  onRadio: offline
                                      ? null
                                      : () => startSongRadio(
                                          videoId: track.videoId,
                                          useCase: ref.read(
                                            startRadioUseCaseProvider,
                                          ),
                                          player: notifier,
                                          feedback: ref.read(
                                            actionFeedbackProvider.notifier,
                                          ),
                                          l10n: l10n,
                                        ),
                                  onOpenLyrics: () =>
                                      _setViewMode(_TvNpViewMode.lyrics),
                                  onOpenQueue: _toggleQueue,
                                )
                              : _TvFullScreenLyricsStage(
                                  song: song,
                                  track: track,
                                  player: player,
                                  notifier: notifier,
                                  playFocusNode: _lyricsPlayFocus,
                                  onBackToArt: () =>
                                      _setViewMode(_TvNpViewMode.artwork),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Slide-in "Up Next" Queue Drawer Overlay
            if (_showQueue)
              _TvQueueDrawer(
                queue: player.queue,
                currentSong: song,
                onClose: _closeQueue,
                onSelectTrack: (index) {
                  notifier.skipToIndex(index);
                  _closeQueue();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Top Navigation & Control Bar
// =============================================================================

class _TvNowPlayingTopBar extends StatelessWidget {
  final _TvNpViewMode viewMode;
  final bool showQueue;
  final int queueCount;
  final String badgeLabel;
  final VoidCallback onBack;
  final ValueChanged<_TvNpViewMode> onSelectMode;
  final VoidCallback onToggleQueue;

  const _TvNowPlayingTopBar({
    required this.viewMode,
    required this.showQueue,
    required this.queueCount,
    required this.badgeLabel,
    required this.onBack,
    required this.onSelectMode,
    required this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        // Back to Catalog Button
        TvFocusable(
          onSelect: onBack,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.chevronLeft,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.askIntroBack,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Center Mode Switcher Pills
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModePill(
                label: l10n.tvStageArtwork,
                icon: LucideIcons.disc,
                selected: viewMode == _TvNpViewMode.artwork,
                onSelect: () => onSelectMode(_TvNpViewMode.artwork),
              ),
              const SizedBox(width: 4),
              _ModePill(
                label: l10n.lyrics,
                icon: LucideIcons.mic2,
                selected: viewMode == _TvNpViewMode.lyrics,
                onSelect: () => onSelectMode(_TvNpViewMode.lyrics),
              ),
              const SizedBox(width: 4),
              _ModePill(
                label: '${l10n.queue} ($queueCount)',
                icon: LucideIcons.listMusic,
                selected: showQueue,
                onSelect: onToggleQueue,
              ),
            ],
          ),
        ),

        const Spacer(),

        // Audio Specs Badges
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            badgeLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;

  const _ModePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TvFocusable(
      onSelect: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? colorScheme.primary : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? colorScheme.primary : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// View 1: Cinematic Artwork Stage
// =============================================================================

class _TvArtworkCinematicStage extends ConsumerWidget {
  final MediaItem song;
  final QueueTrack track;
  final PlayerState player;
  final PlayerNotifier notifier;
  final FocusNode playFocusNode;
  final bool liked;
  final bool shuffled;
  final VoidCallback onLike;
  final VoidCallback? onRadio;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQueue;

  const _TvArtworkCinematicStage({
    required this.song,
    required this.track,
    required this.player,
    required this.notifier,
    required this.playFocusNode,
    required this.liked,
    required this.shuffled,
    required this.onLike,
    required this.onRadio,
    required this.onOpenLyrics,
    required this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final artUrl = song.artUri?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Hero Artwork & Spinning Vinyl Disc
            _TvSpinningVinylArtwork(
              imageUrl: artUrl,
              isPlaying: player.isPlaying,
              reduceEffects: reduceEffects,
              isEpisode: track.isEpisode,
            ),

            const SizedBox(width: 44),

            // Right Track Metadata, Progress, and Transport Controls
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Now Playing Eyebrow + Animated EQ Bars
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          l10n.nowPlaying,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (player.isPlaying) ...[
                        const SizedBox(width: 10),
                        _TvAnimatedEqBars(
                          color: colorScheme.primary,
                          animate: !reduceEffects,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Title (Large 10-foot scale)
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: TvColors.textPrimary,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Artist
                  Text(
                    song.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (song.album != null && song.album!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      song.album!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: TvColors.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Seek Bar
                  _TvSeekBar(player: player, notifier: notifier),

                  const SizedBox(height: 18),

                  // Primary Remote Transport Controls
                  Row(
                    children: [
                      _CircleControl(
                        icon: LucideIcons.shuffle,
                        selected: shuffled,
                        onSelect: () => notifier.toggleShuffle(),
                        size: 42,
                      ),
                      const SizedBox(width: 14),
                      _CircleControl(
                        icon: LucideIcons.skipBack,
                        onSelect: () => notifier.skipToPrevious(),
                        size: 48,
                        tonal: true,
                      ),
                      const SizedBox(width: 14),
                      // Giant Hero Play/Pause Button
                      _CircleControl(
                        focusNode: playFocusNode,
                        icon: player.isPlaying
                            ? LucideIcons.pause
                            : LucideIcons.play,
                        onSelect: () => notifier.togglePlayPause(),
                        size: 64,
                        filled: true,
                        autofocus: true,
                      ),
                      const SizedBox(width: 14),
                      _CircleControl(
                        icon: LucideIcons.skipForward,
                        onSelect: () => notifier.skipToNext(),
                        size: 48,
                        tonal: true,
                      ),
                      const SizedBox(width: 14),
                      _CircleControl(
                        icon: player.repeatMode == AudioServiceRepeatMode.one
                            ? LucideIcons.repeat1
                            : LucideIcons.repeat,
                        selected:
                            player.repeatMode != AudioServiceRepeatMode.none,
                        onSelect: () => notifier.cycleRepeatMode(),
                        size: 42,
                      ),
                      const SizedBox(width: 14),
                      _CircleControl(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        selected: liked,
                        onSelect: onLike,
                        size: 42,
                      ),
                      if (onRadio != null) ...[
                        const SizedBox(width: 14),
                        _CircleControl(
                          icon: LucideIcons.radio,
                          onSelect: onRadio,
                          size: 42,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Secondary Quick Jump Links: Lyrics & Queue
                  Row(
                    children: [
                      TvFocusable(
                        onSelect: onOpenLyrics,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.mic2,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.lyrics,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TvFocusable(
                        onSelect: onOpenQueue,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.listMusic,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.queue,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// View 2: Full-Screen Karaoke Lyrics Stage
// =============================================================================

class _TvFullScreenLyricsStage extends StatelessWidget {
  final MediaItem song;
  final QueueTrack track;
  final PlayerState player;
  final PlayerNotifier notifier;
  final FocusNode playFocusNode;
  final VoidCallback onBackToArt;

  const _TvFullScreenLyricsStage({
    required this.song,
    required this.track,
    required this.player,
    required this.notifier,
    required this.playFocusNode,
    required this.onBackToArt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final artUrl = song.artUri?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              // Lyrics Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    ThumbnailWidget(
                      imageUrl: artUrl,
                      size: 40,
                      shape: ThumbnailShape.rounded,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            song.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TvFocusable(
                      onSelect: onBackToArt,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.disc,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.tvStageArtwork,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white12),

              // Lyrics Flow (Standalone 10-foot Karaoke Stage)
              Expanded(
                child: _TvKaraokeLyricsBody(
                  videoId: track.videoId,
                  position: player.position,
                ),
              ),

              const Divider(height: 1, color: Colors.white12),

              // Compact Bottom Control Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    TvFocusable(
                      onSelect: () => notifier.skipToPrevious(),
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        LucideIcons.skipBack,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    TvFocusable(
                      focusNode: playFocusNode,
                      autofocus: true,
                      onSelect: () => notifier.togglePlayPause(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                        ),
                        child: Icon(
                          player.isPlaying
                              ? LucideIcons.pause
                              : LucideIcons.play,
                          size: 18,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TvFocusable(
                      onSelect: () => notifier.skipToNext(),
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        LucideIcons.skipForward,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_fmtDuration(player.position)} / ${_fmtDuration(player.duration)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 359999);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// =============================================================================
// View 3: Slide-in Queue Drawer Overlay
// =============================================================================

class _TvQueueDrawer extends StatelessWidget {
  final List<MediaItem> queue;
  final MediaItem currentSong;
  final VoidCallback onClose;
  final ValueChanged<int> onSelectTrack;

  const _TvQueueDrawer({
    required this.queue,
    required this.currentSong,
    required this.onClose,
    required this.onSelectTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 340,
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.arrowLeft)) {
            onClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            border: Border(
              left: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 40,
                offset: Offset(-10, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        l10n.queue,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${queue.length})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      TvFocusable(
                        autofocus: queue.isEmpty,
                        onSelect: onClose,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            LucideIcons.x,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white12),

                // Queue List
                Expanded(
                  child: queue.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noSongsInMix,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            final isCurrent = item.id == currentSong.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: TvFocusable(
                                autofocus: isCurrent,
                                onSelect: () => onSelectTrack(index),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.4,
                                            )
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: isCurrent
                                              ? colorScheme.primary
                                              : Colors.white38,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ThumbnailWidget(
                                        imageUrl: item.artUri?.toString(),
                                        size: 36,
                                        shape: ThumbnailShape.rounded,
                                        borderRadius: 6,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isCurrent
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isCurrent
                                                    ? colorScheme.primary
                                                    : Colors.white,
                                              ),
                                            ),
                                            if (item.artist != null)
                                              Text(
                                                item.artist!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Primitives & Seek Bar
// =============================================================================

class _CircleControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onSelect;
  final double size;
  final bool filled;
  final bool tonal;
  final bool selected;
  final bool autofocus;
  final FocusNode? focusNode;

  const _CircleControl({
    required this.icon,
    required this.onSelect,
    required this.size,
    this.filled = false,
    this.tonal = false,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = filled
        ? colorScheme.primary
        : tonal
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.08);
    final fg = filled
        ? colorScheme.onPrimary
        : selected
        ? colorScheme.primary
        : Colors.white;

    // Avoid InkWell inside TvFocusable: InkWell registers its own FocusNode
    // which steals D-pad focus away from TvFocusable.
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onSelect: onSelect,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: size * 0.44, color: fg),
      ),
    );
  }
}

/// TV seek strip with D-Pad Left/Right seek scrubbing.
class _TvSeekBar extends StatefulWidget {
  final PlayerState player;
  final PlayerNotifier notifier;

  const _TvSeekBar({required this.player, required this.notifier});

  @override
  State<_TvSeekBar> createState() => _TvSeekBarState();
}

class _TvSeekBarState extends State<_TvSeekBar> {
  final FocusNode _node = FocusNode(debugLabel: 'tvSeekBar');
  bool _focused = false;

  static const _seekStep = Duration(seconds: 10);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.notifier.seekBy(-_seekStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.notifier.seekBy(_seekStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _fmt(Duration d) {
    final total = d.inSeconds.clamp(0, 359999);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = widget.player.duration;
    final position = widget.player.position;
    final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final progress = (position.inMilliseconds / maxMs).clamp(0.0, 1.0);

    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      onFocusChange: (hasFocus) {
        if (_focused != hasFocus) setState(() => _focused = hasFocus);
      },
      child: AnimatedContainer(
        duration: TvMetrics.drawerAnimDuration,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _fmt(position),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt(duration),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 256×256dp hero artwork stage with Pulse glow and rotating vinyl record disc.
class _TvSpinningVinylArtwork extends StatefulWidget {
  final String? imageUrl;
  final bool isPlaying;
  final bool reduceEffects;
  final bool isEpisode;

  const _TvSpinningVinylArtwork({
    required this.imageUrl,
    required this.isPlaying,
    required this.reduceEffects,
    required this.isEpisode,
  });

  @override
  State<_TvSpinningVinylArtwork> createState() =>
      _TvSpinningVinylArtworkState();
}

class _TvSpinningVinylArtworkState extends State<_TvSpinningVinylArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _TvSpinningVinylArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldSpin =
        widget.isPlaying && !widget.reduceEffects && !widget.isEpisode;
    if (shouldSpin && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!shouldSpin && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = 256.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: widget.reduceEffects
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.38),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black87,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: TvColors.surfaceCard),
            ThumbnailWidget(
              imageUrl: widget.imageUrl,
              size: size,
              shape: ThumbnailShape.square,
              borderRadius: 0,
            ),
            if (!widget.isEpisode)
              Center(
                child: RotationTransition(
                  turns: _spinController,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TvColors.bg.withValues(alpha: 0.84),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 12),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 8,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TvAnimatedEqBars extends StatefulWidget {
  final Color color;
  final bool animate;

  const _TvAnimatedEqBars({required this.color, required this.animate});

  @override
  State<_TvAnimatedEqBars> createState() => _TvAnimatedEqBarsState();
}

class _TvAnimatedEqBarsState extends State<_TvAnimatedEqBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _TvAnimatedEqBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = widget.animate ? _controller.value * math.pi * 2 : 1.0;
          final h1 = 4.0 + 9.0 * ((math.sin(t) + 1) / 2);
          final h2 = 4.0 + 10.0 * ((math.sin(t + 2.1) + 1) / 2);
          final h3 = 4.0 + 8.0 * ((math.sin(t + 4.2) + 1) / 2);
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(h1),
              const SizedBox(width: 2),
              _bar(h2),
              const SizedBox(width: 2),
              _bar(h3),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double h) {
    return Container(
      width: 2.5,
      height: h,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Standalone 10-foot Karaoke Lyrics stage matching the Canvas specification:
/// centered large typography, neon cyan pill highlight on the active synced
/// line with smooth auto-scroll, and D-pad scrollable fallback for plain lyrics.
class _TvKaraokeLyricsBody extends ConsumerWidget {
  final String videoId;
  final Duration position;

  const _TvKaraokeLyricsBody({required this.videoId, required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timedAsync = ref.watch(lyricsProvider(videoId));
    final plainAsync = ref.watch(plainLyricsProvider(videoId));
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return timedAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      error: (_, _) => _buildPlain(context, plainAsync, l10n),
      data: (timed) {
        if (timed != null && timed.timedLyricsData.isNotEmpty) {
          return _TvSyncedKaraokeList(lyrics: timed, position: position);
        }
        return _buildPlain(context, plainAsync, l10n);
      },
    );
  }

  Widget _buildPlain(
    BuildContext context,
    AsyncValue<String?> plainAsync,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return plainAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      error: (_, _) => _TvEmptyLyrics(message: l10n.lyricsNotAvailable),
      data: (text) {
        if (text == null || text.trim().isEmpty) {
          return _TvEmptyLyrics(message: l10n.lyricsNotAvailable);
        }
        return _TvPlainScrollableLyrics(text: text);
      },
    );
  }
}

class _TvEmptyLyrics extends StatelessWidget {
  final String message;

  const _TvEmptyLyrics({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.micOff,
            size: 44,
            color: TvColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: TvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TvPlainScrollableLyrics extends StatefulWidget {
  final String text;

  const _TvPlainScrollableLyrics({required this.text});

  @override
  State<_TvPlainScrollableLyrics> createState() =>
      _TvPlainScrollableLyricsState();
}

class _TvPlainScrollableLyricsState extends State<_TvPlainScrollableLyrics> {
  final ScrollController _scroll = ScrollController();
  bool _focused = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_scroll.hasClients) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        _scroll.offset < _scroll.position.maxScrollExtent - 2) {
      _scroll.animateTo(
        (_scroll.offset + 120).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && _scroll.offset > 2) {
      _scroll.animateTo(
        (_scroll.offset - 120).clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Focus(
      onFocusChange: (v) {
        if (_focused != v) setState(() => _focused = v);
      },
      onKeyEvent: _onKey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(
              color: _focused
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
        ),
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: TvColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _TvSyncedKaraokeList extends StatefulWidget {
  final TimedLyricsRes lyrics;
  final Duration position;

  const _TvSyncedKaraokeList({required this.lyrics, required this.position});

  @override
  State<_TvSyncedKaraokeList> createState() => _TvSyncedKaraokeListState();
}

class _TvSyncedKaraokeListState extends State<_TvSyncedKaraokeList> {
  int _lastActiveIndex = -1;
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(
      widget.lyrics.timedLyricsData.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(covariant _TvSyncedKaraokeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics.timedLyricsData.length !=
        oldWidget.lyrics.timedLyricsData.length) {
      _keys = List.generate(
        widget.lyrics.timedLyricsData.length,
        (_) => GlobalKey(),
      );
    }

    final active = _activeIndex();
    if (active != _lastActiveIndex && active < _keys.length) {
      _lastActiveIndex = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _keys[active].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            alignment: 0.45,
          );
        }
      });
    }
  }

  int _activeIndex() {
    final data = widget.lyrics.timedLyricsData;
    final posMs = widget.position.inMilliseconds;
    var active = 0;
    for (var i = 0; i < data.length; i++) {
      final start = data[i].cueRange?.startTimeMilliseconds;
      if (start != null && start <= posMs) {
        active = i;
      }
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.lyrics.timedLyricsData;
    final activeIndex = _activeIndex();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      child: Column(
        children: List.generate(data.length, (index) {
          final text = data[index].lyricLine?.trim() ?? '';
          if (text.isEmpty) {
            return SizedBox(key: _keys[index], height: 18);
          }
          final isActive = index == activeIndex;
          final isNext = index == activeIndex + 1;

          if (isActive) {
            return Container(
              key: _keys[index],
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            );
          }

          return Padding(
            key: _keys[index],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isNext
                    ? TvColors.textPrimary.withValues(alpha: 0.78)
                    : TvColors.textSecondary.withValues(alpha: 0.65),
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                height: 1.35,
              ),
            ),
          );
        }),
      ),
    );
  }
}
