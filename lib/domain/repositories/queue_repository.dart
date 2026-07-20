import 'package:audio_service/audio_service.dart';

import '../models/queue_playback_meta.dart';
import '../models/queue_track.dart';

/// Domain interface for queue persistence.
/// Decouples [PlayerNotifier]/[SonoraAudioHandler] from the Drift data layer.
///
/// The queue items and the "where were we" pointer ([QueuePlaybackMeta]) are
/// persisted together atomically (see [persistQueue]) so a process death
/// between the two writes can never leave them disagreeing — the historical
/// cause of resuming into the wrong track after the app had been killed by
/// the OS between sessions.
abstract class QueueRepository {
  /// Atomically replaces the persisted queue with [items] AND the
  /// current-index/videoId pointer, in a single transaction.
  ///
  /// [currentIndex] must index into [items].
  ///
  /// [position]/[shuffleMode]/[repeatMode] default to `null`, meaning
  /// "leave whatever is already persisted for this field alone" — a
  /// structural queue change (add/remove/reorder) should NOT reset the last
  /// known playback position or shuffle/repeat mode just because the
  /// queue's shape changed. Pass them explicitly only when they are
  /// actually known to have changed (e.g. `position: Duration.zero` when
  /// starting a brand-new playback session via setQueue/playNow). See
  /// [persistPosition]/[persistPlaybackModes] for lightweight, queue-table-
  /// free alternatives for the frequent update case.
  Future<void> persistQueue(
    List<MediaItem> items, {
    required int currentIndex,
    Duration? position,
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
  });

  /// Loads the persisted queue ordered by position as typed [QueueTrack]s.
  /// Stream URLs may be stale; callers should resolve/refresh them as needed.
  Future<List<QueueTrack>> restoreQueue();

  /// Loads the persisted "where were we" pointer. Always returns a value —
  /// [QueuePlaybackMeta.empty] when nothing has been persisted yet.
  Future<QueuePlaybackMeta> restoreMeta();

  /// Lightweight update of only the current index/videoId anchor, without
  /// touching the queue table. Safe to call on every track change (e.g.
  /// skipToNext/Previous/QueueItem) even when the queue's structure itself
  /// hasn't changed, so the "where were we" pointer never lags behind the
  /// actual playing track.
  Future<void> persistCurrentIndex(int index, {String? videoId});

  /// Lightweight update of only the last known playback position, without
  /// touching the queue table. Safe to call frequently (e.g. on every pause
  /// or periodic tick) since it never rewrites the (potentially large)
  /// queue item list.
  Future<void> persistPosition(Duration position);

  /// Lightweight update of shuffle/repeat mode only, without touching the
  /// queue table.
  Future<void> persistPlaybackModes({
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
  });

  /// Deletes all persisted queue items and resets the playback pointer.
  Future<void> clearQueue();

  /// Deletes only the persisted items belonging to the user queue
  /// (`section = 'user'`), preserving the autoplay "Up Next" section.
  Future<void> clearUserQueue();
}
