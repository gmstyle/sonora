import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:sonora/data/services/media_cache_service.dart';
import 'package:sonora/data/services/sabr_proxy_session.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

SabrAudioStreamInfo _makeSabrAudio(int totalBytes) {
  final bootstrap = SabrBootstrap(
    videoId: 'abcdefghijk',
    serverAbrStreamingUrl: 'https://rr1.googlevideo.com/videoplayback?id=1',
    videoPlaybackUstreamerConfig: Uint8List.fromList([1, 2, 3]),
    clientNameId: 101,
    clientVersion: '1.02',
    audioFormat: const SabrFormatId(251, lastModified: 1700000),
    discardVideoFormat: const SabrFormatId(160, lastModified: 1700000),
    discardVideoHeight: 144,
    durationMs: 10000,
    contentLengthBytes: totalBytes,
    mimeType: 'audio/webm',
  );
  return SabrAudioStreamInfo(
    VideoId('abcdefghijk'),
    251,
    Uri.parse('https://rr1.googlevideo.com/videoplayback?id=1'),
    StreamContainer.webM,
    FileSize(totalBytes),
    Bitrate(128000),
    'opus',
    'medium',
    const [],
    MediaType('audio', 'webm'),
    null,
    bootstrap,
    const Duration(seconds: 10),
  );
}

void main() {
  group('SabrProxySession', () {
    late Directory tempRoot;
    late Directory cacheDir;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('sonora_sabr_test_');
      cacheDir = Directory('${tempRoot.path}/cache')..createSync();
      MediaCacheService.instance.debugCacheDir = cacheDir;
    });

    tearDown(() async {
      MediaCacheService.instance.debugCacheDir = null;
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('serves 200 OK full stream, 206 partial ranges, promotes cache, and cleans up temp file', () async {
      final initBytes = Uint8List.fromList([0, 1, 2, 3]);
      final seg1Bytes = Uint8List.fromList([4, 5, 6, 7, 8, 9]);
      final seg2Bytes = Uint8List.fromList([10, 11, 12, 13, 14, 15]);
      final allBytes = [...initBytes, ...seg1Bytes, ...seg2Bytes];
      final openStarts = <int>[];

      final session = SabrProxySession(
        videoId: 'sabrVid1',
        sabrStream: _makeSabrAudio(allBytes.length),
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) {
          openStarts.add(initialPlayerTimeMs);
          return Stream.fromIterable([
            SabrChunk(data: initBytes, startRange: 0, isInitialization: true),
            SabrChunk(
              data: seg1Bytes,
              startRange: 4,
              isInitialization: false,
              sequenceNumber: 1,
              startMs: 0,
              durationMs: 5000,
            ),
            SabrChunk(
              data: seg2Bytes,
              startRange: 10,
              isInitialization: false,
              sequenceNumber: 2,
              startMs: 5000,
              durationMs: 5000,
            ),
          ]);
        },
      );

      final resp200 = await session.serveRange(null);
      expect(resp200.statusCode, 200);
      expect(resp200.headers['Accept-Ranges'], 'bytes');
      expect(resp200.headers['Content-Length'], '${allBytes.length}');
      final body200 = await resp200.read().expand((e) => e).toList();
      expect(body200, orderedEquals(allBytes));
      expect(openStarts, [0]);

      // Subsequent range read uses the already buffered temp file without reopening SABR.
      final resp206 = await session.serveRange('bytes=5-12');
      expect(resp206.statusCode, 206);
      expect(resp206.headers['Content-Range'], 'bytes 5-12/${allBytes.length}');
      expect(resp206.headers['Content-Length'], '8');
      final body206 = await resp206.read().expand((e) => e).toList();
      expect(body206, orderedEquals(allBytes.sublist(5, 13)));
      expect(openStarts, [0]);

      // Give background promotion a moment to settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final cachedUri = await MediaCacheService.instance.getCachedFileUri(
        'sabrVid1',
      );
      expect(cachedUri, isNotNull);

      await session.dispose();
      final leftovers = tempRoot
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('triggers time-based SABR restart on far forward seek', () async {
      final openStarts = <int>[];
      final totalBytes = 2 * 1024 * 1024;
      final seekOffset = 1024 * 1024; // > 512 KiB threshold

      final tailController = StreamController<SabrChunk>();
      final session = SabrProxySession(
        videoId: 'sabrSeek1',
        sabrStream: _makeSabrAudio(totalBytes),
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) {
          openStarts.add(initialPlayerTimeMs);
          if (initialPlayerTimeMs == 0) {
            // Only emit init so cursor stays at 4 bytes.
            return Stream.fromIterable([
              SabrChunk(
                data: Uint8List.fromList([1, 2, 3, 4]),
                startRange: 0,
                isInitialization: true,
              ),
            ]).asyncExpand((chunk) async* {
              yield chunk;
              await Future<void>.delayed(const Duration(seconds: 5));
            });
          }
          return tailController.stream;
        },
      );
      addTearDown(session.dispose);

      // Start initial pump briefly so cursor is at 4, well below seekOffset.
      final firstResp = await session.serveRange('bytes=0-3');
      expect(await firstResp.read().expand((e) => e).toList(), [1, 2, 3, 4]);

      final seekResp = await session.serveRange(
        'bytes=$seekOffset-${seekOffset + 3}',
      );
      tailController.add(
        SabrChunk(
          data: Uint8List.fromList([42, 43, 44, 45]),
          startRange: seekOffset,
          isInitialization: false,
          sequenceNumber: 10,
          startMs: 5000,
          durationMs: 1000,
        ),
      );
      final seekBytes = await seekResp.read().expand((e) => e).toList();
      expect(seekBytes, [42, 43, 44, 45]);
      expect(openStarts.length, 2);
      expect(openStarts.last, greaterThan(0));
      await tailController.close();
    });

    test('estimates proportional forward seek time even after earlier segments are recorded', () async {
      final openStarts = <int>[];
      final totalBytes = 2 * 1024 * 1024;
      final seekOffset = 1024 * 1024; // 50% of totalBytes -> ~5000ms
      final tailController = StreamController<SabrChunk>();

      final session = SabrProxySession(
        videoId: 'sabrSeekScaled',
        sabrStream: _makeSabrAudio(totalBytes), // durationMs = 10000
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) {
          openStarts.add(initialPlayerTimeMs);
          if (initialPlayerTimeMs == 0) {
            return Stream.fromIterable([
              SabrChunk(
                data: Uint8List.fromList([1, 2, 3, 4]),
                startRange: 0,
                isInitialization: true,
              ),
              SabrChunk(
                data: Uint8List.fromList([5, 6, 7, 8]),
                startRange: 4,
                isInitialization: false,
                sequenceNumber: 1,
                startMs: 0,
                durationMs: 2000,
              ),
            ]).asyncExpand((chunk) async* {
              yield chunk;
              await Future<void>.delayed(const Duration(seconds: 5));
            });
          }
          return tailController.stream;
        },
      );
      addTearDown(session.dispose);

      // Read first segment so _segmentTimings has startByte=4, startMs=0 recorded.
      final firstResp = await session.serveRange('bytes=0-7');
      expect(await firstResp.read().expand((e) => e).toList(), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);

      final seekResp = await session.serveRange(
        'bytes=$seekOffset-${seekOffset + 3}',
      );
      tailController.add(
        SabrChunk(
          data: Uint8List.fromList([90, 91, 92, 93]),
          startRange: seekOffset,
          isInitialization: false,
          sequenceNumber: 10,
          startMs: 5000,
          durationMs: 2000,
        ),
      );
      expect(await seekResp.read().expand((e) => e).toList(), [90, 91, 92, 93]);
      expect(openStarts.length, 2);
      expect(openStarts.last, inInclusiveRange(4500, 5500));
      await tailController.close();
    });

    test('dispose waits for cache promotion before deleting temp file and stops waiting readers cleanly', () async {
      final initBytes = Uint8List.fromList([1, 2, 3, 4]);
      final segBytes = Uint8List.fromList([5, 6, 7, 8, 9, 10]);
      final allBytes = [...initBytes, ...segBytes];

      final session = SabrProxySession(
        videoId: 'sabrPromoteDispose',
        sabrStream: _makeSabrAudio(allBytes.length),
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) => Stream.fromIterable([
          SabrChunk(data: initBytes, startRange: 0, isInitialization: true),
          SabrChunk(
            data: segBytes,
            startRange: 4,
            isInitialization: false,
            sequenceNumber: 1,
            startMs: 0,
            durationMs: 10000,
          ),
        ]),
      );

      final resp = await session.serveRange(null);
      expect(
        await resp.read().expand((e) => e).toList(),
        orderedEquals(allBytes),
      );
      // Dispose immediately without sleeping: must await promoteFileToCache first.
      await session.dispose();

      final cachedUri = await MediaCacheService.instance.getCachedFileUri(
        'sabrPromoteDispose',
      );
      expect(cachedUri, isNotNull);
      final leftovers = tempRoot
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);

      // Waiting reader terminates cleanly without StateError when disposed mid-wait.
      final stalledController = StreamController<SabrChunk>();
      final stalledSession = SabrProxySession(
        videoId: 'sabrDisposeWait',
        sabrStream: _makeSabrAudio(100),
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) => stalledController.stream,
      );
      final waitResp = await stalledSession.serveRange('bytes=0-9');
      final readFuture = waitResp.read().expand((e) => e).toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await stalledSession.dispose();
      await expectLater(readFuture, completes);
      await stalledController.close();
    });

    test('handles concurrent far range requests cleanly and triggers onRateLimited on 429', () async {
      final totalBytes = 2 * 1024 * 1024;
      final farOffset = 1024 * 1024;
      var rateLimitedCalls = 0;

      final headControllers = <StreamController<SabrChunk>>[];
      final farController = StreamController<SabrChunk>();

      final session = SabrProxySession(
        videoId: 'sabrConcurrent',
        sabrStream: _makeSabrAudio(totalBytes),
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) {
          if (initialPlayerTimeMs == 0) {
            final c = StreamController<SabrChunk>();
            headControllers.add(c);
            return c.stream;
          }
          return farController.stream;
        },
        onRateLimited: () => rateLimitedCalls++,
      );
      addTearDown(session.dispose);

      final headResp = await session.serveRange('bytes=0-3');
      final headFuture = headResp.read().expand((e) => e).toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Second concurrent request at farOffset interrupts initial pump.
      final farResp = await session.serveRange(
        'bytes=$farOffset-${farOffset + 3}',
      );
      final farFuture = farResp.read().expand((e) => e).toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      farController.add(
        SabrChunk(
          data: Uint8List.fromList([77, 78, 79, 80]),
          startRange: farOffset,
          isInitialization: false,
          sequenceNumber: 20,
          startMs: 5000,
          durationMs: 1000,
        ),
      );
      expect(await farFuture, [77, 78, 79, 80]);

      // Allow headFuture to re-open its pump at 0 and serve 0..3.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      headControllers.last.add(
        SabrChunk(
          data: Uint8List.fromList([11, 12, 13, 14]),
          startRange: 0,
          isInitialization: true,
        ),
      );
      expect(await headFuture, [11, 12, 13, 14]);
      for (final c in headControllers) {
        await c.close();
      }
      await farController.close();

      // Separate session verifying 429 callback.
      final rateLimitSession = SabrProxySession(
        videoId: 'sabr429',
        sabrStream: _makeSabrAudio(100),
        tempDir: tempRoot,
        openChunks: ({int initialPlayerTimeMs = 0}) => Stream.error(
          SabrProtocolException(
            'SABR request failed with HTTP 429',
            kind: SabrFailureKind.network,
            httpStatusCode: 429,
          ),
        ),
        onRateLimited: () => rateLimitedCalls++,
      );
      addTearDown(rateLimitSession.dispose);

      final errResp = await rateLimitSession.serveRange('bytes=0-9');
      await expectLater(
        errResp.read().drain<void>(),
        throwsA(isA<SabrProtocolException>()),
      );
      expect(rateLimitedCalls, 1);
    });
  });
}
