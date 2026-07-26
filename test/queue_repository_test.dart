import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/queue_repository_impl.dart';
import 'package:sonora/domain/models/queue_track.dart';

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

  test(
    'persistQueue and restoreQueue saves and restores entire queue correctly',
    () async {
      final items = [
        QueueTrack(
          videoId: 'song_1',
          title: 'Song 1',
          artist: 'Artist 1',
          url: 'https://example.com/stream1.mp3',
        ).toFreshMediaItem(),
        QueueTrack(
          videoId: 'song_2',
          title: 'Song 2',
          artist: 'Artist 2',
          needsUrl: true,
        ).toFreshMediaItem(),
      ];

      // Persist queue
      await repo.persistQueue(items, currentIndex: 0);

      // Restore queue
      final restored = await repo.restoreQueue();

      expect(restored.length, 2);

      // Verify first item (resolved URL)
      expect(restored[0].videoId, 'song_1');
      expect(restored[0].title, 'Song 1');
      expect(restored[0].url, 'https://example.com/stream1.mp3');
      expect(restored[0].needsUrl, false);

      // Verify second item (pending URL)
      expect(restored[1].videoId, 'song_2');
      expect(restored[1].title, 'Song 2');
      expect(restored[1].url, isNull);
      expect(restored[1].needsUrl, true);
    },
  );
}
