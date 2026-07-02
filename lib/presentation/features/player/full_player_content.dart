import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/palette_provider.dart';
import 'widgets/player_shared_widgets.dart';
import 'layouts/mobile_player_layout.dart';
import 'layouts/tablet_player_layout.dart';
import 'layouts/wide_player_layout.dart';
import 'layouts/fullscreen_overlay_layout.dart';

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
  final GlobalKey _artworkKey = GlobalKey(debugLabel: 'player_artwork');

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
              !isPortrait &&
              (availableWidth < kCompactBreakpoint ||
                  availableHeight < kCompactBreakpoint);
          final showFullscreenOverlay =
              isLandscapeMobile && activeView != PlayerSubView.none;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildPlayerBackground(artUrl, theme)),
              if (showFullscreenOverlay)
                FullscreenOverlayLayout(
                  currentSong: currentSong,
                  isVideo: isVideo,
                  videoId: videoId,
                  artUrl: artUrl,
                  albumName: albumName,
                  playerState: playerState,
                  playerNotifier: playerNotifier,
                  hasSleepTimer: hasSleepTimer,
                  bottomInset: padding.bottom,
                  activeView: activeView,
                  onClose: () => _subViewNotifier.set(PlayerSubView.none),
                )
              else if (availableWidth < kCompactBreakpoint || isPortrait)
                MobilePlayerLayout(
                  artworkKey: _artworkKey,
                  currentSong: currentSong,
                  isVideo: isVideo,
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
                )
              else if (availableWidth < kExpandedBreakpoint)
                TabletPlayerLayout(
                  artworkKey: _artworkKey,
                  currentSong: currentSong,
                  isVideo: isVideo,
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
                )
              else
                WidePlayerLayout(
                  artworkKey: _artworkKey,
                  currentSong: currentSong,
                  isVideo: isVideo,
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
                ),
            ],
          );
        },
      ),
    );
  }

  // ─── Background ──────────────────────────────────────────────

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
}
