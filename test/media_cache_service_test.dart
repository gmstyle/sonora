import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/services/media_cache_service.dart';

void main() {
  late Directory cacheDir;
  final cache = MediaCacheService.instance;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('sonora_cache_test_');
    cache.debugCacheDir = cacheDir;
    cache.debugMaxCacheSizeBytes = null;
  });

  tearDown(() async {
    cache.debugCacheDir = null;
    cache.debugMaxCacheSizeBytes = null;
    cache.maxCacheSizeBytes = 1024 * 1024 * 1024;
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  Future<File> writeCache(String name, {int bytes = 8}) async {
    final file = File('${cacheDir.path}/$name');
    await file.writeAsBytes(List<int>.filled(bytes, 1));
    return file;
  }

  group('getCachedHit / getCachedFileUri', () {
    test('returns only audio-only, never .v.* or muxed', () async {
      await writeCache('vid.webm');
      await writeCache('vid.v.mp4');
      await writeCache('vid.mp4');

      final hit = await cache.getCachedHit('vid');
      expect(hit, isNotNull);
      expect(hit!.primaryUri, contains('vid.webm'));

      final uri = await cache.getCachedFileUri('vid');
      expect(uri, contains('vid.webm'));
      expect(uri, isNot(contains('.v.')));
      expect(uri, isNot(contains('vid.mp4')));
    });

    test('is a miss when only muxed or video-only exist', () async {
      await writeCache('vid.v.mp4');
      await writeCache('vid.mp4');

      expect(await cache.getCachedHit('vid'), isNull);
      expect(await cache.getCachedFileUri('vid'), isNull);
    });

    test('pair leftovers still yield the audio-only sibling', () async {
      await writeCache('vid.v.mp4');
      await writeCache('vid.webm');

      final hit = await cache.getCachedHit('vid');
      expect(hit!.primaryUri, contains('vid.webm'));
      expect(await cache.getCachedFileUri('vid'), contains('vid.webm'));
    });

    test('audio-only exists without video is still an audio hit', () async {
      await writeCache('song.webm');

      final hit = await cache.getCachedHit('song');
      expect(hit!.primaryUri, contains('song.webm'));
    });
  });

  group('LRU sibling rules', () {
    test('evicting audio-only also deletes the video-only sibling', () async {
      final audio = await writeCache('old.webm', bytes: 100);
      final video = await writeCache('old.v.mp4', bytes: 100);
      final other = await writeCache('keep.mp3', bytes: 100);
      final old = DateTime.now().subtract(const Duration(hours: 2));
      final mid = DateTime.now().subtract(const Duration(hours: 1));
      final recent = DateTime.now();
      await audio.setLastModified(old);
      await video.setLastModified(mid);
      await other.setLastModified(recent);

      cache.debugMaxCacheSizeBytes = 150;
      await cache.debugEnforceSizeLimit();

      expect(await audio.exists(), isFalse);
      expect(await video.exists(), isFalse);
      expect(await other.exists(), isTrue);
    });

    test('evicting video-only leaves the audio-only sibling', () async {
      final video = await writeCache('clip.v.mp4', bytes: 100);
      final audio = await writeCache('clip.webm', bytes: 100);
      final other = await writeCache('other.mp3', bytes: 100);
      final old = DateTime.now().subtract(const Duration(hours: 2));
      final mid = DateTime.now().subtract(const Duration(hours: 1));
      final recent = DateTime.now();
      await video.setLastModified(old);
      await audio.setLastModified(mid);
      await other.setLastModified(recent);

      cache.debugMaxCacheSizeBytes = 250;
      await cache.debugEnforceSizeLimit();

      expect(await video.exists(), isFalse);
      expect(await audio.exists(), isTrue);
      expect(await other.exists(), isTrue);
    });

    test('evicting muxed mp4 deletes only that file', () async {
      final muxed = await writeCache('mix.mp4', bytes: 100);
      final audio = await writeCache('mix.webm', bytes: 100);
      final old = DateTime.now().subtract(const Duration(hours: 2));
      final recent = DateTime.now();
      await muxed.setLastModified(old);
      await audio.setLastModified(recent);

      cache.debugMaxCacheSizeBytes = 150;
      await cache.debugEnforceSizeLimit();

      expect(await muxed.exists(), isFalse);
      expect(await audio.exists(), isTrue);
    });

    test(
      'setMaxCacheSizeBytes lowers the cap and evicts without wipe',
      () async {
        final old = await writeCache('old.webm', bytes: 100);
        final keep = await writeCache('keep.webm', bytes: 100);
        await old.setLastModified(
          DateTime.now().subtract(const Duration(hours: 2)),
        );
        await keep.setLastModified(DateTime.now());

        await cache.setMaxCacheSizeBytes(150);

        expect(await old.exists(), isFalse);
        expect(await keep.exists(), isTrue);
        expect(cache.maxCacheSizeBytes, 150);
      },
    );
  });
}
