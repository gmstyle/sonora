import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart';

import '../../domain/repositories/queue_repository.dart';
import '../datasources/local/database.dart';

class QueueRepositoryImpl implements QueueRepository {
  final AppDatabase _db;

  QueueRepositoryImpl(this._db);

  @override
  Future<void> persistQueue(List<MediaItem> items) async {
    // Skip pending items (needsUrl) — they have no stream URL and are
    // ephemeral; the player resolves them lazily when they are about to play.
    final filtered =
        items.where((item) => item.extras?['needsUrl'] != true).toList();

    await _db.batch((batch) {
      batch.deleteAll(_db.queueItems);
      for (int i = 0; i < filtered.length; i++) {
        final item = filtered[i];
        batch.insert(
          _db.queueItems,
          QueueItemsCompanion.insert(
            position: Value(i),
            videoId: item.id,
            title: item.title,
            artist: item.artist ?? '',
            albumTitle: Value(item.album),
            thumbnailUrl: Value(item.artUri?.toString()),
            durationSec: Value(item.duration?.inSeconds),
            isVideo: item.extras?['isVideo'] == true,
            streamUrl: Value(item.extras?['url'] as String?),
          ),
        );
      }
    });
  }

  @override
  Future<List<MediaItem>> restoreQueue() async {
    final rows = await _db.select(_db.queueItems).get();
    rows.sort((a, b) => a.position.compareTo(b.position));
    return rows.map((row) {
      return MediaItem(
        id: row.videoId,
        title: row.title,
        artist: row.artist,
        album: row.albumTitle,
        duration: Duration(seconds: row.durationSec ?? 0),
        artUri:
            row.thumbnailUrl != null ? Uri.tryParse(row.thumbnailUrl!) : null,
        extras: {
          if (row.streamUrl != null && row.streamUrl!.isNotEmpty)
            'url': row.streamUrl,
          'videoId': row.videoId,
          'isVideo': row.isVideo,
        },
      );
    }).toList();
  }

  @override
  Future<void> clearQueue() => _db.delete(_db.queueItems).go();
}
