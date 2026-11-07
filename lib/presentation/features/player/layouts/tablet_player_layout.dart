import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/palette_provider.dart';
import '../../../providers/player_insights_provider.dart';
import '../../../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_insights_panel.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/top_bar.dart';
import '../widgets/artwork.dart';
import '../widgets/player_bouncing_widget.dart';
import '../widgets/up_next_companion.dart';

/// Tablet full player: disc on the left, controls then up next on the right.
///
/// A panel replaces the list. The disc and the transport stay.
class TabletPlayerLayout extends ConsumerWidget {
  const TabletPlayerLayout({
    super.key,
    required this.artworkKey,
    required this.currentSong,
    required this.videoId,
    required this.artUrl,
    required this.albumName,
    required this.playerState,
    required this.playerNotifier,
    required this.hasSleepTimer,
    required this.availHeight,
    required this.availWidth,
    required this.bottomInset,
    required this.activeView,
  });

  final GlobalKey artworkKey;
  final MediaItem currentSong;
  final String videoId;
  final String? artUrl;
  final String? albumName;
  final PlayerState playerState;
  final PlayerNotifier playerNotifier;
  final bool hasSleepTimer;
  final double availHeight;
  final double availWidth;
  final double bottomInset;
  final PlayerSubView activeView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tight = availHeight < 600;
    final narrow = availWidth < 720;
    final insightsOpen = ref.watch(playerInsightsProvider).isOpen;
    final panelOpen = activeView != PlayerSubView.none;
    final exclusive = panelOpen || insightsOpen;
    final hPad = narrow ? 16.0 : 32.0;
    final colGap = narrow ? 16.0 : 32.0;
    final artSide = min(360.0, availWidth * 0.46);
    final artSize = min(
      artSide - 8,
      availHeight * (tight ? 0.46 : 0.58),
    ).clamp(120.0, 360.0);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hPad,
          vertical: tight ? 4 : 16,
        ),
        child: Column(
          children: [
            TopBar(currentSong: currentSong, albumName: albumName),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: artSide,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Artwork(
                          key: artworkKey,
                          artUrl: artUrl,
                          size: artSize,
                          minSize: min(artSize, 150),
                          videoId: videoId,
                          isSwitching: playerState.isSwitching,
                        ),
                        SizedBox(height: tight ? 8 : 16),
                        _visualizer(context, ref),
                        const PlayerSleepBadge(),
                      ],
                    ),
                  ),
                  SizedBox(width: colGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: tight ? 4 : 12),
                        buildTrackInfoAndLikeRow(context, ref, currentSong),
                        SizedBox(height: tight ? 8 : 12),
                        buildProgressBar(context, ref, playerState),
                        SizedBox(height: tight ? 4 : 12),
                        const PlayerControls(),
                        buildBottomActionsRow(
                          context,
                          ref,
                          hasSleepTimer,
                          playerNotifier,
                          activeView,
                        ),
                        SizedBox(height: tight ? 8 : 12),
                        Expanded(
                          child: exclusive
                              ? _exclusive(panelOpen)
                              : const UpNextCompanion(maxItems: 6),
                        ),
                      ],
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

  Widget _exclusive(bool panelOpen) {
    if (panelOpen) {
      return buildPlayerSubPanel(
        activeView: activeView,
        videoId: videoId,
        position: playerState.position,
      );
    }
    return const SingleChildScrollView(child: PlayerInsightsCard());
  }

  Widget _visualizer(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteNotifierProvider)[videoId];
    final color =
        palette?.dominantColor ??
        Theme.of(context).colorScheme.primaryContainer;
    final playing = playerState.isPlaying && !playerState.isLoading;
    return AudioVisualizer(isPlaying: playing, color: color, height: 36);
  }
}
