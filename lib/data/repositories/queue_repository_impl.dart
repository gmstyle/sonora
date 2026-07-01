import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart';

import '../../domain/repositories/queue_repository.dart';
import '../datasources/local/database.dart';

class QueueRepositoryImpl implements QueueRepository {
  final AppDatabase _db;

  QueueRepositoryImpl(this._db);

  @override
  Future<void> persistQueue(List<MediaItem> items) async {
    await _db.batch((batch) {
      batch.deleteAll(_db.queueItems);
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
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
            artistId: Value(item.extras?['artistId'] as String?),
            albumId: Value(item.extras?['albumId'] as String?),
            isExplicit: Value(item.extras?['isExplicit'] == true),
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
      final hasUrl = row.streamUrl != null && row.streamUrl!.isNotEmpty;
      return MediaItem(
        id: row.videoId,
        title: row.title,
        artist: row.artist,
        album: row.albumTitle,
        duration: Duration(seconds: row.durationSec ?? 0),
        artUri:
            row.thumbnailUrl != null ? Uri.tryParse(row.thumbnailUrl!) : null,
        extras: {
          if (hasUrl) 'url': row.streamUrl else 'needsUrl': true,
          'videoId': row.videoId,
          'isVideo': row.isVideo,
          'isExplicit': row.isExplicit,
          if (row.artistId != null) 'artistId': row.artistId,
          if (row.albumId != null) 'albumId': row.albumId,
        },
      );
    }).toList();
  }

  @override
  Future<void> clearQueue() => _db.delete(_db.queueItems).go();
}
