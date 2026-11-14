import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/utils/screen_keep_awake.dart';
import '../../providers/lyrics_translation_provider.dart';
import '../../providers/player_insights_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../domain/models/queue_track.dart';
import '../../providers/palette_provider.dart';
import 'widgets/player_shared_widgets.dart';
import 'layouts/mobile_player_layout.dart';
import 'layouts/tablet_player_layout.dart';
import 'layouts/wide_player_layout.dart';
import '../../providers/android_tv_provider.dart';
import '../tv/screens/tv_now_playing_screen.dart';

/// Pushes [FullPlayerContent] with the same slide-up used by every shell.
void openFullPlayer(
  BuildContext context, {
  PlayerSubView subView = PlayerSubView.none,
}) {
  final container = ProviderScope.containerOf(context);
  if (container.read(isAndroidTvProvider)) {
    openTvNowPlaying(context, lyrics: subView == PlayerSubView.lyrics);
    return;
  }
  if (subView != PlayerSubView.none) {
    container.read(playerSubViewProvider.notifier).set(subView);
  }
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          FullPlayerContent(initialSubView: subView),
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
  late final PlayerSubViewNotifier _subViewNotifier;
  late final PlayerQueueDrawerNotifier _queueDrawer;
  final GlobalKey _artworkKey = GlobalKey(debugLabel: 'player_artwork');

  /// Last sub-view applied to [ScreenKeepAwake]; avoids spam on rebuilds.
  PlayerSubView? _keepAwakeForView;

  @override
  void initState() {
    super.initState();
    _subViewNotifier = ref.read(playerSubViewProvider.notifier);
    _queueDrawer = ref.read(playerQueueDrawerProvider.notifier);
    if (widget.initialSubView != PlayerSubView.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _subViewNotifier.set(widget.initialSubView);
      });
    }
  }

  @override
  void dispose() {
    // Fire-and-forget: leave the sheet must never leave FLAG_KEEP_SCREEN_ON.
    ScreenKeepAwake.disable();
    Future.microtask(() {
      _subViewNotifier.set(PlayerSubView.none);
      _queueDrawer.set(false);
    });
    super.dispose();
  }

  void _syncLyricsKeepAwake(PlayerSubView view) {
    if (_keepAwakeForView == view) return;
    _keepAwakeForView = view;
    if (view == PlayerSubView.lyrics) {
      ScreenKeepAwake.enable();
    } else {
      ScreenKeepAwake.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final activeView = ref.watch(playerSubViewProvider);

    // Keep the display awake only while the lyrics sub-view is open (Android).
    ref.listen<PlayerSubView>(playerSubViewProvider, (prev, next) {
      _syncLyricsKeepAwake(next);
    });
    _syncLyricsKeepAwake(activeView);

    ref.listen<String?>(
      playerStateProvider.select(
        (s) => s.currentSong == null
            ? null
            : QueueTrack.fromMediaItem(s.currentSong!).videoId,
      ),
      (prev, next) {
        if (prev == next) return;
        ref.read(playerInsightsProvider.notifier).onTrackChanged(next);
        ref.read(lyricsTranslationProvider.notifier).onTrackChanged(next);
      },
    );

    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final track = QueueTrack.fromMediaItem(currentSong);
    final videoId = track.videoId;
    final artUrl = currentSong.artUri?.toString();
    final albumName = currentSong.album;
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewPadding;
    final hasSleepTimer = playerState.hasSleepTimer;

    // ── Palette ───────────────────────────────────────────────────
    final paletteMap = ref.watch(paletteNotifierProvider);
    final paletteData = paletteMap[videoId];
    final dominantColor =
        paletteData?.dominantColor ?? theme.colorScheme.primaryContainer;
    final isDark = paletteData?.isDark ?? true;
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
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight =
              constraints.maxHeight - padding.top - padding.bottom;
          final availableWidth = constraints.maxWidth;
          final window = MediaQuery.sizeOf(context);
          final layoutArgs = (
            artworkKey: _artworkKey,
            currentSong: currentSong,
            videoId: videoId,
            artUrl: artUrl,
            albumName: albumName,
            playerState: playerState,
            playerNotifier: playerNotifier,
            hasSleepTimer: hasSleepTimer,
            availHeight: availableHeight,
            availWidth: availableWidth,
            bottomInset: padding.bottom,
            activeView: activeView,
          );

          final Widget layout;
          if (isCompactShell(window)) {
            layout = MobilePlayerLayout(
              artworkKey: layoutArgs.artworkKey,
              currentSong: layoutArgs.currentSong,
              videoId: layoutArgs.videoId,
              artUrl: layoutArgs.artUrl,
              albumName: layoutArgs.albumName,
              playerState: layoutArgs.playerState,
              playerNotifier: layoutArgs.playerNotifier,
              hasSleepTimer: layoutArgs.hasSleepTimer,
              availHeight: layoutArgs.availHeight,
              availWidth: layoutArgs.availWidth,
              bottomInset: layoutArgs.bottomInset,
              activeView: layoutArgs.activeView,
            );
          } else if (isWideShell(window)) {
            layout = WidePlayerLayout(
              artworkKey: layoutArgs.artworkKey,
              currentSong: layoutArgs.currentSong,
              videoId: layoutArgs.videoId,
              artUrl: layoutArgs.artUrl,
              albumName: layoutArgs.albumName,
              playerState: layoutArgs.playerState,
              playerNotifier: layoutArgs.playerNotifier,
              hasSleepTimer: layoutArgs.hasSleepTimer,
              availHeight: layoutArgs.availHeight,
              availWidth: layoutArgs.availWidth,
              bottomInset: layoutArgs.bottomInset,
              activeView: layoutArgs.activeView,
            );
          } else {
            layout = TabletPlayerLayout(
              artworkKey: layoutArgs.artworkKey,
              currentSong: layoutArgs.currentSong,
              videoId: layoutArgs.videoId,
              artUrl: layoutArgs.artUrl,
              albumName: layoutArgs.albumName,
              playerState: layoutArgs.playerState,
              playerNotifier: layoutArgs.playerNotifier,
              hasSleepTimer: layoutArgs.hasSleepTimer,
              availHeight: layoutArgs.availHeight,
              availWidth: layoutArgs.availWidth,
              bottomInset: layoutArgs.bottomInset,
              activeView: layoutArgs.activeView,
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _buildPlayerBackground(
                  artUrl,
                  theme,
                  dominantColor,
                  isDark,
                ),
              ),
              layout,
            ],
          );
        },
      ),
    );
  }

  // ─── Background ──────────────────────────────────────────────

  Widget _buildPlayerBackground(
    String? artUrl,
    ThemeData theme,
    Color dominantColor,
    bool isDark,
  ) {
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    return buildPlayerBackground(
      artUrl,
      dominantColor,
      isDark,
      theme.colorScheme,
      context: context,
      reduceEffects: reduceEffects,
    );
  }
}
