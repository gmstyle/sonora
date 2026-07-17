import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/queue_repository_impl.dart';
import 'package:sonora/domain/models/queue_section.dart';

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

  group('QueueSection enum', () {
    test('tag returns the expected string for each variant', () {
      expect(QueueSection.user.tag, 'user');
      expect(QueueSection.upnext.tag, 'upnext');
    });

    test('fromTag returns user for null / unknown / legacy values', () {
      expect(QueueSection.fromTag(null), QueueSection.user);
      expect(QueueSection.fromTag(''), QueueSection.user);
      expect(QueueSection.fromTag('something'), QueueSection.user);
      expect(QueueSection.fromTag('user'), QueueSection.user);
      expect(QueueSection.fromTag('upnext'), QueueSection.upnext);
    });
  });

  group('QueueRepository section persistence', () {
    test('persistQueue preserves the section tag for each item', () async {
      final items = [
        MediaItem(
          id: 'user_song',
          title: 'User song',
          artist: 'Artist',
          extras: {
            'url': 'https://example.com/a.mp3',
            'videoId': 'user_song',
            'isVideo': false,
            'section': 'user',
          },
        ),
        MediaItem(
          id: 'upnext_song',
          title: 'Upnext song',
          artist: 'Artist',
          extras: {
            'needsUrl': true,
            'videoId': 'upnext_song',
            'isVideo': false,
            'section': 'upnext',
          },
        ),
      ];

      await repo.persistQueue(items);
      final restored = await repo.restoreQueue();

      expect(restored.length, 2);
      expect(restored[0].extras?['section'], 'user');
      expect(restored[1].extras?['section'], 'upnext');
    });

    test(
      'restoreQueue defaults missing section to user (legacy rows)',
      () async {
        final items = [
          MediaItem(
            id: 'legacy',
            title: 'Legacy song',
            artist: 'Artist',
            extras: {
              'url': 'https://example.com/legacy.mp3',
              'videoId': 'legacy',
              'isVideo': false,
              // No 'section' key — simulates a row written before schema 18.
            },
          ),
        ];

        await repo.persistQueue(items);
        final restored = await repo.restoreQueue();

        expect(restored.single.extras?['section'], 'user');
      },
    );

    test('persisted positions are restored in order across sections', () async {
      final items = [
        MediaItem(
          id: 'a',
          title: 'A',
          artist: 'X',
          extras: {
            'url': 'https://e/a.mp3',
            'videoId': 'a',
            'isVideo': false,
            'section': 'user',
          },
        ),
        MediaItem(
          id: 'b',
          title: 'B',
          artist: 'X',
          extras: {
            'url': 'https://e/b.mp3',
            'videoId': 'b',
            'isVideo': false,
            'section': 'user',
          },
        ),
        MediaItem(
          id: 'c',
          title: 'C',
          artist: 'X',
          extras: {
            'url': 'https://e/c.mp3',
            'videoId': 'c',
            'isVideo': false,
            'section': 'upnext',
          },
        ),
      ];

      await repo.persistQueue(items);
      final restored = await repo.restoreQueue();

      expect(restored.map((it) => it.id).toList(), ['a', 'b', 'c']);
      expect(restored[0].extras?['section'], 'user');
      expect(restored[1].extras?['section'], 'user');
      expect(restored[2].extras?['section'], 'upnext');
    });
  });
}
