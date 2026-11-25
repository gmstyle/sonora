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
  });
}
