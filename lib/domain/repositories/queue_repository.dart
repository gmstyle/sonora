import 'package:audio_service/audio_service.dart';

/// Domain interface for queue persistence.
/// Decouples [PlayerNotifier] from the Drift data layer.
abstract class QueueRepository {
  /// Atomically replaces the persisted queue with [items].
  Future<void> persistQueue(List<MediaItem> items);

  /// Loads the persisted queue ordered by position.
  /// Stream URLs stored in [MediaItem.extras] may be stale; callers
  /// should resolve/refresh them as needed.
  Future<List<MediaItem>> restoreQueue();

  /// Deletes all persisted queue items.
  Future<void> clearQueue();

  /// Deletes only the persisted items belonging to the user queue
  /// (`section = 'user'`), preserving the autoplay "Up Next" section.
  Future<void> clearUserQueue();
}
