import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/data/services/local_audio_proxy_server.dart';
import 'package:sonora/domain/models/media_quality.dart';

class MockStreamDatasource extends StreamDatasource {
  bool invalidateCalled = false;
  MediaQuality? lastAudioQuality;

  @override
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? audioQuality,
    int attempt = 1,
  }) async {
    lastAudioQuality = audioQuality;
    return 'http://example.com/test_stream.mp3';
  }

  @override
  void invalidateCache(String videoId) {
    invalidateCalled = true;
    super.invalidateCache(videoId);
  }
}

void main() {
  group('LocalAudioProxyServer', () {
    late MockStreamDatasource mockStreamDs;
    late LocalAudioProxyServer proxyServer;
    late HttpClient httpClient;

    setUp(() async {
      mockStreamDs = MockStreamDatasource();
      proxyServer = LocalAudioProxyServer(streamDatasource: mockStreamDs);
      await proxyServer.start();
      httpClient = HttpClient();
    });

    tearDown(() async {
      httpClient.close();
      await proxyServer.stop();
    });

    test('Server starts on ephemeral loopback port', () {
      expect(proxyServer.isRunning, isTrue);
      expect(proxyServer.port, greaterThan(0));
      expect(
        proxyServer.streamBaseUrl,
        equals('http://127.0.0.1:${proxyServer.port}'),
      );
    });

    test('getStreamUrlForVideo generates valid local URL', () {
      final videoId = 'test_vid_123';
      final url = proxyServer.getStreamUrlForVideo(videoId);
      expect(
        url,
        equals(
          'http://127.0.0.1:${proxyServer.port}/stream?videoId=$videoId&qa=high',
        ),
      );
    });

    test('getStreamUrlForVideo includes audio quality only', () {
      final url = proxyServer.getStreamUrlForVideo(
        'vid',
        audioQuality: MediaQuality.mid,
      );
      expect(
        url,
        equals(
          'http://127.0.0.1:${proxyServer.port}/stream?videoId=vid&qa=mid',
        ),
      );
      expect(url, isNot(contains('v=')));
      expect(url, isNot(contains('qv=')));
      expect(url, isNot(contains('kind=')));
    });

    test('legacy q query maps to audio quality', () async {
      final req = await httpClient.getUrl(
        Uri.parse(
          'http://127.0.0.1:${proxyServer.port}/stream?videoId=vid&q=mid',
        ),
      );
      final res = await req.close();
      await res.drain();
      expect(res.statusCode, isNot(400));
      expect(mockStreamDs.lastAudioQuality, MediaQuality.mid);
    });

    test('Missing videoId returns 400 Bad Request', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:${proxyServer.port}/stream'),
      );
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      expect(res.statusCode, equals(400));
      expect(body, contains('Missing videoId parameter'));
    });
  });
}
