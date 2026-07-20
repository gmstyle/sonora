import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../domain/models/queue_playback_meta.dart';
import '../../domain/models/queue_section.dart';
import '../../domain/repositories/queue_repository.dart';
import '../datasources/local/database.dart';

class QueueRepositoryImpl implements QueueRepository {
  final AppDatabase _db;

  QueueRepositoryImpl(this._db);

  /// Fixed id of the single [QueueMeta] row.
  static const int _metaRowId = 0;

  @override
  Future<void> persistQueue(
    List<MediaItem> items, {
    required int currentIndex,
    // `null` (the default) means "leave whatever is already persisted
    // alone" — see the `Value.absent()` handling below. Structural queue
    // changes (add/remove/reorder) call this WITHOUT a position/mode, and
    // must not clobber the last known playback position or shuffle/repeat
    // mode just because the queue's shape changed. Only call sites that
    // genuinely start a brand-new playback session (setQueue/playNow) pass
    // `position: Duration.zero` explicitly.
    Duration? position,
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
  }) async {
    final anchorVideoId =
        currentIndex >= 0 && currentIndex < items.length
            ? items[currentIndex].id
            : null;

    // Single transaction: the queue rows and the "where were we" pointer
    // are written together, so a process death mid-write can never leave
    // one persisted without the other — either both land, or neither does.
    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.deleteAll(_db.queueItems);
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final section =
              QueueSection.fromTag(item.extras?['section'] as String?).tag;
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
              section: Value(section),
            ),
          );
        }
      });

      await _db
          .into(_db.queueMeta)
          .insertOnConflictUpdate(
            QueueMetaCompanion.insert(
              id: const Value(_metaRowId),
              currentIndex: Value(currentIndex < 0 ? 0 : currentIndex),
              currentVideoId: Value(anchorVideoId),
              positionMs:
                  position != null
                      ? Value(position.inMilliseconds)
                      : const Value.absent(),
              shuffleMode:
                  shuffleMode != null
                      ? Value(shuffleMode.name)
                      : const Value.absent(),
              repeatMode:
                  repeatMode != null
                      ? Value(repeatMode.name)
                      : const Value.absent(),
              updatedAt: Value(DateTime.now()),
            ),
          );
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
          'section': QueueSection.fromTag(row.section).tag,
          if (row.artistId != null) 'artistId': row.artistId,
          if (row.albumId != null) 'albumId': row.albumId,
        },
      );
    }).toList();
  }

  @override
  Future<QueuePlaybackMeta> restoreMeta() async {
    final row =
        await (_db.select(_db.queueMeta)
          ..where((t) => t.id.equals(_metaRowId))).getSingleOrNull();
    if (row == null) return QueuePlaybackMeta.empty;

    return QueuePlaybackMeta(
      currentIndex: row.currentIndex,
      currentVideoId: row.currentVideoId,
      position: Duration(milliseconds: row.positionMs),
      shuffleMode: AudioServiceShuffleMode.values.firstWhereOrNull(
        (m) => m.name == row.shuffleMode,
      ),
      repeatMode: AudioServiceRepeatMode.values.firstWhereOrNull(
        (m) => m.name == row.repeatMode,
      ),
    );
  }

  @override
  Future<void> persistCurrentIndex(int index, {String? videoId}) async {
    await _db
        .into(_db.queueMeta)
        .insertOnConflictUpdate(
          QueueMetaCompanion.insert(
            id: const Value(_metaRowId),
            currentIndex: Value(index < 0 ? 0 : index),
            currentVideoId: Value(videoId),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> persistPosition(Duration position) async {
    await _db
        .into(_db.queueMeta)
        .insertOnConflictUpdate(
          QueueMetaCompanion.insert(
            id: const Value(_metaRowId),
            positionMs: Value(position.inMilliseconds),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> persistPlaybackModes({
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
  }) async {
    // `Value.absent()` (rather than `Value(null)`) for a mode that wasn't
    // passed in — insertOnConflictUpdate leaves absent columns untouched on
    // the existing row, so toggling shuffle doesn't wipe out the previously
    // persisted repeat mode, and vice versa.
    await _db
        .into(_db.queueMeta)
        .insertOnConflictUpdate(
          QueueMetaCompanion.insert(
            id: const Value(_metaRowId),
            shuffleMode:
                shuffleMode != null
                    ? Value(shuffleMode.name)
                    : const Value.absent(),
            repeatMode:
                repeatMode != null
                    ? Value(repeatMode.name)
                    : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> clearQueue() async {
    await _db.transaction(() async {
      await _db.delete(_db.queueItems).go();
      await (_db.delete(_db.queueMeta)
        ..where((t) => t.id.equals(_metaRowId))).go();
    });
  }

  @override
  Future<void> clearUserQueue() =>
      (_db.delete(_db.queueItems)..where((t) => t.section.equals('user'))).go();
}
