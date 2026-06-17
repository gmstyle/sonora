import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/queue_repository_impl.dart';

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
        MediaItem(
          id: 'song_1',
          title: 'Song 1',
          artist: 'Artist 1',
          extras: {
            'url': 'https://example.com/stream1.mp3',
            'videoId': 'song_1',
            'isVideo': false,
          },
        ),
        MediaItem(
          id: 'song_2',
          title: 'Song 2',
          artist: 'Artist 2',
          extras: {'needsUrl': true, 'videoId': 'song_2', 'isVideo': false},
        ),
      ];

      // Persist queue
      await repo.persistQueue(items);

      // Restore queue
      final restored = await repo.restoreQueue();

      expect(restored.length, 2);

      // Verify first item (resolved URL)
      expect(restored[0].id, 'song_1');
      expect(restored[0].title, 'Song 1');
      expect(restored[0].extras?['url'], 'https://example.com/stream1.mp3');
      expect(restored[0].extras?['needsUrl'], isNull);

      // Verify second item (pending URL)
      expect(restored[1].id, 'song_2');
      expect(restored[1].title, 'Song 2');
      expect(restored[1].extras?['url'], isNull);
      expect(restored[1].extras?['needsUrl'], true);
    },
  );
}
