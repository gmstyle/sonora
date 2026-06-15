import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/top_bar.dart';
import '../widgets/artwork.dart';

class MobilePlayerLayout extends ConsumerWidget {
  const MobilePlayerLayout({
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
    final theme = Theme.of(context);

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
              TopBar(
                currentSong: currentSong,
                isVideo: isVideo,
                albumName: albumName,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      activeView == PlayerSubView.none
                          ? Center(
                            key: const ValueKey('artwork'),
                            child: GestureDetector(
                              onHorizontalDragEnd: (details) {
                                if (playerState.isSwitching ||
                                    details.primaryVelocity == null) {
                                  return;
                                }
                                if (details.primaryVelocity! < -250) {
                                  HapticFeedback.lightImpact();
                                  playerNotifier.skipToNext();
                                } else if (details.primaryVelocity! > 250) {
                                  HapticFeedback.lightImpact();
                                  playerNotifier.skipToPrevious();
                                }
                              },
                              child: Artwork(
                                artUrl: artUrl,
                                size: min(availWidth - 48, availHeight - 360),
                                videoId: videoId,
                                isSwitching: playerState.isSwitching,
                                isVideo: isVideo,
                              ),
                            ),
                          )
                          : activeView == PlayerSubView.lyrics
                          ? LyricsView(
                            key: const ValueKey('lyrics'),
                            videoId: videoId,
                            position: playerState.position,
                          )
                          : const QueueSheet(key: ValueKey('queue')),
                ),
              ),
              const SizedBox(height: 32),
              buildTrackInfoAndLikeRow(context, ref, currentSong, isVideo),
              const SizedBox(height: 16),
              buildProgressBar(ref, playerState, videoId),
              const SizedBox(height: 16),
              const PlayerControls(),
              const SizedBox(height: 8),
              buildBottomActionsRow(
                context,
                ref,
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
}
