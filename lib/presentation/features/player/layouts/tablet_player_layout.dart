import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../providers/player_provider.dart';
import 'wide_player_layout.dart';

/// Tablet full player, aligned with the wide now-playing page.
///
/// The current cover fills the first screen, with the previous and next
/// covers set apart on either side and titled on a bottom scrim. Artist,
/// album, and related stack in a single column below it. Lyrics and notes
/// replace that scroll. The queue
/// and curiosities open from the right, with curiosities capped at half the
/// window. Track info, transport, and the actions sit in the bottom bar.
class TabletPlayerLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return WidePlayerLayout(
      artworkKey: artworkKey,
      currentSong: currentSong,
      videoId: videoId,
      artUrl: artUrl,
      albumName: albumName,
      playerState: playerState,
      playerNotifier: playerNotifier,
      hasSleepTimer: hasSleepTimer,
      availHeight: availHeight,
      availWidth: availWidth,
      bottomInset: bottomInset,
      activeView: activeView,
      tablet: true,
    );
  }
}
