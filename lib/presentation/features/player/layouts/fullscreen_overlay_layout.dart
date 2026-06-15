import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/top_bar.dart';

class FullscreenOverlayLayout extends ConsumerWidget {
  const FullscreenOverlayLayout({
    super.key,
    required this.currentSong,
    required this.isVideo,
    required this.videoId,
    required this.artUrl,
    required this.albumName,
    required this.playerState,
    required this.playerNotifier,
    required this.hasSleepTimer,
    required this.bottomInset,
    required this.activeView,
    required this.onClose,
  });

  final MediaItem currentSong;
  final bool isVideo;
  final String videoId;
  final String? artUrl;
  final String? albumName;
  final PlayerState playerState;
  final PlayerNotifier playerNotifier;
  final bool hasSleepTimer;
  final double bottomInset;
  final PlayerSubView activeView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            TopBar(
              currentSong: currentSong,
              isVideo: isVideo,
              albumName: albumName,
              onClose: onClose,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child:
                    activeView == PlayerSubView.lyrics
                        ? LyricsView(
                          key: const ValueKey('lyrics'),
                          videoId: videoId,
                          position: playerState.position,
                        )
                        : const QueueSheet(key: ValueKey('queue')),
              ),
            ),
            const SizedBox(height: 12),
            buildProgressBar(ref, playerState, videoId),
            const SizedBox(height: 12),
            const PlayerControls(),
            const SizedBox(height: 4),
            buildBottomActionsRow(
              context,
              ref,
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
}
