import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/queue_repository_impl.dart';

/// Covers the atomic queue+meta persistence introduced to fix Android's
/// "resumes into the wrong track" bug: the current index/videoId/position/
/// shuffle/repeat pointer now lives in the same Drift database as the queue
/// items, written in the same transaction, instead of being split across
/// SharedPreferences and the queue table.
void main() {
  late AppDatabase db;
  late QueueRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = QueueRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  MediaItem song(String id) => MediaItem(
    id: id,
    title: id,
    artist: 'Artist',
    extras: {'url': 'https://example.com/$id.mp3', 'videoId': id},
  );

  group('restoreMeta', () {
    test('returns empty defaults when nothing has been persisted', () async {
      final meta = await repo.restoreMeta();
      expect(meta.currentIndex, 0);
      expect(meta.currentVideoId, isNull);
      expect(meta.position, Duration.zero);
      expect(meta.shuffleMode, isNull);
      expect(meta.repeatMode, isNull);
    });

    test('persistQueue writes index and videoId anchor atomically', () async {
      final items = [song('a'), song('b'), song('c')];
      await repo.persistQueue(items, currentIndex: 1);

      final meta = await repo.restoreMeta();
      expect(meta.currentIndex, 1);
      expect(meta.currentVideoId, 'b');
    });

    test(
      'persistQueue does not reset position/shuffle/repeat when not passed '
      '(a structural queue change must not clobber unrelated state)',
      () async {
        await repo.persistQueue(
          [song('a')],
          currentIndex: 0,
          position: const Duration(seconds: 42),
          shuffleMode: AudioServiceShuffleMode.all,
          repeatMode: AudioServiceRepeatMode.one,
        );

        // Simulate a later structural change (e.g. appendUpNext) that only
        // knows about the index, not the other fields.
        await repo.persistQueue([song('a'), song('b')], currentIndex: 0);

        final meta = await repo.restoreMeta();
        expect(meta.position, const Duration(seconds: 42));
        expect(meta.shuffleMode, AudioServiceShuffleMode.all);
        expect(meta.repeatMode, AudioServiceRepeatMode.one);
      },
    );

    test(
      'persistQueue(position: Duration.zero) explicitly resets position',
      () async {
        await repo.persistQueue(
          [song('a')],
          currentIndex: 0,
          position: const Duration(seconds: 42),
        );
        await repo.persistQueue(
          [song('a')],
          currentIndex: 0,
          position: Duration.zero,
        );

        final meta = await repo.restoreMeta();
        expect(meta.position, Duration.zero);
      },
    );
  });

  group('persistCurrentIndex', () {
    test(
      'updates only the index/videoId, leaving the queue table intact',
      () async {
        final items = [song('a'), song('b')];
        await repo.persistQueue(items, currentIndex: 0);

        await repo.persistCurrentIndex(1, videoId: 'b');

        final meta = await repo.restoreMeta();
        expect(meta.currentIndex, 1);
        expect(meta.currentVideoId, 'b');

        final restoredItems = await repo.restoreQueue();
        expect(restoredItems.map((e) => e.id).toList(), ['a', 'b']);
      },
    );
  });

  group('persistPosition', () {
    test('updates only the position, leaving index/modes untouched', () async {
      await repo.persistQueue(
        [song('a')],
        currentIndex: 0,
        shuffleMode: AudioServiceShuffleMode.all,
      );

      await repo.persistPosition(const Duration(seconds: 10));

      final meta = await repo.restoreMeta();
      expect(meta.position, const Duration(seconds: 10));
      expect(meta.currentIndex, 0);
      expect(meta.shuffleMode, AudioServiceShuffleMode.all);
    });
  });

  group('persistPlaybackModes', () {
    test(
      'setting shuffle alone does not clobber a previously set repeat mode',
      () async {
        await repo.persistPlaybackModes(repeatMode: AudioServiceRepeatMode.all);
        await repo.persistPlaybackModes(
          shuffleMode: AudioServiceShuffleMode.all,
        );

        final meta = await repo.restoreMeta();
        expect(meta.shuffleMode, AudioServiceShuffleMode.all);
        expect(meta.repeatMode, AudioServiceRepeatMode.all);
      },
    );
  });

  group('clearQueue', () {
    test('resets both the queue table and the meta pointer', () async {
      await repo.persistQueue(
        [song('a'), song('b')],
        currentIndex: 1,
        position: const Duration(seconds: 5),
      );

      await repo.clearQueue();

      expect(await repo.restoreQueue(), isEmpty);
      final meta = await repo.restoreMeta();
      expect(meta.currentIndex, 0);
      expect(meta.currentVideoId, isNull);
    });
  });
}
