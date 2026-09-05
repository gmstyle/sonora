import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/presentation/features/player/track_url_resolver.dart';

MediaItem _item(QueueTrack track) => track.toFreshMediaItem();

void main() {
  group('TrackUrlResolver.shouldPrefetchDiskCache', () {
    test('returns true for resolved remote URLs', () {
      final item = _item(
        const QueueTrack(
          videoId: 'abc',
          title: 'Song',
          url: 'https://googlevideo.com/audio.mp3',
        ),
      );
      expect(TrackUrlResolver.shouldPrefetchDiskCache(item), isTrue);
    });

    test(
      'returns true for unresolved needsUrl items (prefetch by videoId)',
      () {
        final item = _item(
          const QueueTrack(videoId: 'abc', title: 'Song', needsUrl: true),
        );
        expect(TrackUrlResolver.shouldPrefetchDiskCache(item), isTrue);
      },
    );

    test('returns false for local file URLs', () {
      final item = _item(
        const QueueTrack(
          videoId: 'abc',
          title: 'Song',
          url: 'file:///tmp/abc.mp3',
        ),
      );
      expect(TrackUrlResolver.shouldPrefetchDiskCache(item), isFalse);
    });

    test('returns true for dummy placeholders (prefetch by videoId)', () {
      final item = _item(
        const QueueTrack(
          videoId: 'abc',
          title: 'Song',
          url: 'http://localhost/dummy_abc.wav',
        ),
      );
      expect(TrackUrlResolver.shouldPrefetchDiskCache(item), isTrue);
    });

    test('returns false for null item', () {
      expect(TrackUrlResolver.shouldPrefetchDiskCache(null), isFalse);
    });

    test('returns false when videoId is empty', () {
      final item = _item(const QueueTrack(videoId: '', title: 'Song'));
      expect(TrackUrlResolver.shouldPrefetchDiskCache(item), isFalse);
    });

    test('prefetches catalog video tracks as audio', () {
      final item = _item(
        const QueueTrack(
          videoId: 'vid',
          title: 'Video',
          isVideo: true,
          url: 'https://googlevideo.com/audio.mp3',
        ),
      );
      expect(TrackUrlResolver.shouldPrefetchDiskCache(item), isTrue);
    });
  });

  group('TrackUrlResolver.stalePrefetchIds', () {
    const queue = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];

    test('keeps downloads inside the current..+3 window', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'a', 'b', 'c', 'd'},
        queueVideoIds: queue,
        currentIndex: 0,
      );
      expect(stale, isEmpty);
    });

    test('returns stale downloads outside the window', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
        queueVideoIds: queue,
        currentIndex: 0,
      );
      expect(stale, {'e', 'f', 'g'});
    });

    test('window follows the current index (skip ahead prunes old ones)', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'a', 'b', 'c', 'd', 'e', 'f'},
        queueVideoIds: queue,
        currentIndex: 3,
      );
      // Window is now d..g; 'a', 'b', 'c' were skipped past.
      expect(stale, {'a', 'b', 'c'});
    });

    test('clamps the window at the end of the queue', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'e', 'f', 'g'},
        queueVideoIds: queue,
        currentIndex: 5,
      );
      // Window is f..g; 'e' is stale.
      expect(stale, {'e'});
    });

    test('keeps nothing beyond the queue length', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'a', 'b', 'c'},
        queueVideoIds: queue,
        currentIndex: 10,
      );
      expect(stale, {'a', 'b', 'c'});
    });

    test('treats every in-flight download as stale for an empty queue', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'a', 'b', 'c'},
        queueVideoIds: const [],
        currentIndex: 0,
      );
      expect(stale, {'a', 'b', 'c'});
    });

    test('ignores null/empty videoIds in the window', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'a', 'b', 'c', 'd', 'e'},
        queueVideoIds: const [null, 'b', '', 'd', null, 'e', 'f'],
        currentIndex: 0,
      );
      // Window covers indices 0..3 -> b, d (null/empty don't keep anything).
      expect(stale, {'a', 'c', 'e'});
    });

    test('deduplicates videoIds appearing twice in the queue', () {
      final stale = TrackUrlResolver.stalePrefetchIds(
        inFlight: {'x', 'z'},
        queueVideoIds: const ['x', 'y', 'x', 'z'],
        currentIndex: 0,
      );
      expect(stale, isEmpty);
    });
  });
}
