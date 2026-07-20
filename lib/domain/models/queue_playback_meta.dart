import 'package:audio_service/audio_service.dart';

/// Persisted "where were we" pointer for the playback queue.
///
/// Bundles the current index, a stable identity anchor ([currentVideoId])
/// for that index, the last known playback position, and the shuffle/repeat
/// mode — everything [SonoraAudioHandler] needs to resume a cold-started
/// session correctly.
///
/// This is always persisted in the *same* transaction as the queue items
/// themselves (see `QueueRepository.persistQueue`), so the index can never
/// silently drift out of sync with the queue on disk the way it could when
/// this pointer lived in `SharedPreferences` while the queue lived in the
/// Drift database.
class QueuePlaybackMeta {
  /// Index into the persisted queue that was playing.
  final int currentIndex;

  /// videoId of the item at [currentIndex] at the time of persistence.
  ///
  /// Used as a fallback anchor when, for legacy/edge-case reasons, the raw
  /// index no longer lines up with the restored queue (e.g. items were
  /// deleted from the queue by an external process between sessions).
  final String? currentVideoId;

  /// Last known playback position of the current item.
  final Duration position;

  final AudioServiceShuffleMode? shuffleMode;
  final AudioServiceRepeatMode? repeatMode;

  const QueuePlaybackMeta({
    required this.currentIndex,
    this.currentVideoId,
    this.position = Duration.zero,
    this.shuffleMode,
    this.repeatMode,
  });

  static const empty = QueuePlaybackMeta(currentIndex: 0);
}
