import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:audio_service/audio_service.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/queue_repository_impl.dart';
import 'package:sonora/domain/models/queue_section.dart';
import 'package:sonora/domain/models/queue_track.dart';

MediaItem _withSection(QueueTrack track, QueueSection section) {
  return track.toFreshMediaItem(additionalExtras: {'section': section.tag});
}

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
        _withSection(
          QueueTrack(
            videoId: 'user_song',
            title: 'User song',
            artist: 'Artist',
            url: 'https://example.com/a.mp3',
          ),
          QueueSection.user,
        ),
        _withSection(
          QueueTrack(
            videoId: 'upnext_song',
            title: 'Upnext song',
            artist: 'Artist',
            needsUrl: true,
          ),
          QueueSection.upnext,
        ),
      ];

      await repo.persistQueue(items, currentIndex: 0);
      final restored = await repo.restoreQueue();

      expect(restored.length, 2);
      // Section is persisted in the DB but not carried on QueueTrack.
      // Verify directly via the DB rows.
      final rows = await db.select(db.queueItems).get();
      rows.sort((a, b) => a.position.compareTo(b.position));
      expect(rows[0].section, 'user');
      expect(rows[1].section, 'upnext');
    });

    test(
      'restoreQueue defaults missing section to user (legacy rows)',
      () async {
        final items = [
          QueueTrack(
            videoId: 'legacy',
            title: 'Legacy song',
            artist: 'Artist',
            url: 'https://example.com/legacy.mp3',
          ).toFreshMediaItem(),
        ];

        await repo.persistQueue(items, currentIndex: 0);
        await repo.restoreQueue();

        final rows = await db.select(db.queueItems).get();
        expect(QueueSection.fromTag(rows.single.section), QueueSection.user);
      },
    );

    test('persisted positions are restored in order across sections', () async {
      final items = [
        _withSection(
          QueueTrack(
            videoId: 'a',
            title: 'A',
            artist: 'X',
            url: 'https://e/a.mp3',
          ),
          QueueSection.user,
        ),
        _withSection(
          QueueTrack(
            videoId: 'b',
            title: 'B',
            artist: 'X',
            url: 'https://e/b.mp3',
          ),
          QueueSection.user,
        ),
        _withSection(
          QueueTrack(
            videoId: 'c',
            title: 'C',
            artist: 'X',
            url: 'https://e/c.mp3',
          ),
          QueueSection.upnext,
        ),
      ];

      await repo.persistQueue(items, currentIndex: 0);
      final restored = await repo.restoreQueue();

      expect(restored.map((it) => it.videoId).toList(), ['a', 'b', 'c']);
      final rows = await db.select(db.queueItems).get();
      rows.sort((a, b) => a.position.compareTo(b.position));
      expect(rows[0].section, 'user');
      expect(rows[1].section, 'user');
      expect(rows[2].section, 'upnext');
    });
  });
}
