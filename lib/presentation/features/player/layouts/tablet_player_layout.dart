import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/top_bar.dart';
import '../widgets/artwork.dart';
import '../widgets/player_bouncing_widget.dart';

class TabletPlayerLayout extends ConsumerWidget {
  const TabletPlayerLayout({
    super.key,
    required this.artworkKey,
    required this.currentSong,
    required this.isVideo,
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
  final bool isVideo;
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
    final isPanelOpen = activeView != PlayerSubView.none;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32.0,
          vertical: tight ? 4.0 : 16.0,
        ),
        child: Column(
          children: [
            TopBar(
              currentSong: currentSong,
              isVideo: isVideo,
              albumName: albumName,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Artwork(
                          key: artworkKey,
                          artUrl: artUrl,
                          size: min(
                            availHeight - (tight ? 70 : 100),
                            availWidth / 2 - 48,
                          ),
                          videoId: videoId,
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: tight ? 2 : 24),
                            buildTrackInfoAndLikeRow(
                              context,
                              ref,
                              currentSong,
                              isVideo,
                            ),
                            SizedBox(height: tight ? 2 : 16),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child:
                                    isPanelOpen
                                        ? (activeView == PlayerSubView.lyrics
                                            ? LyricsView(
                                              key: const ValueKey('lyrics'),
                                              videoId: videoId,
                                              position: playerState.position,
                                            )
                                            : const QueueSheet(
                                              key: ValueKey('queue'),
                                            ))
                                        : PlayerDefaultView(
                                          key: const ValueKey('empty'),
                                          tight: tight,
                                        ),
                              ),
                            ),
                            SizedBox(height: tight ? 2 : 16),
                            buildProgressBar(ref, playerState, videoId),
                            SizedBox(height: tight ? 2 : 16),
                            const PlayerControls(),
                            SizedBox(height: tight ? 0 : 8),
                            buildBottomActionsRow(
                              context,
                              ref,
                              isVideo,
                              hasSleepTimer,
                              playerNotifier,
                              activeView,
                            ),
                            SizedBox(height: tight ? 2 : 16),
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
}
