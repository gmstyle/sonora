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

class WidePlayerLayout extends ConsumerWidget {
  const WidePlayerLayout({
    super.key,
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
          horizontal: 64.0,
          vertical: tight ? 8.0 : 32.0,
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
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Artwork(
                          artUrl: artUrl,
                          size: min(
                            availHeight - (tight ? 100 : 150),
                            availWidth / 2 - 100,
                          ),
                          videoId: videoId,
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: tight ? 2 : 32),
                            buildTrackInfoAndLikeRow(
                              context,
                              ref,
                              currentSong,
                              isVideo,
                            ),
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
                                        : const SizedBox.shrink(
                                          key: ValueKey('empty'),
                                        ),
                              ),
                            ),
                            SizedBox(height: tight ? 2 : 16),
                            buildProgressBar(ref, playerState, videoId),
                            SizedBox(height: tight ? 2 : 24),
                            const PlayerControls(),
                            SizedBox(height: tight ? 2 : 16),
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
