import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/data/services/local_audio_proxy_server.dart';
import 'package:sonora/domain/models/media_quality.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/domain/repositories/queue_repository.dart';
import 'package:sonora/presentation/features/player/queue_controller.dart';
import 'helpers/fake_playback_engine.dart';

class _FakeStreamDatasource extends StreamDatasource {
  @override
  Future<String> getStreamUrl(
    String videoId, {
    MediaQuality? audioQuality,
    int attempt = 1,
  }) async {
    return 'http://example.com/$videoId.mp3';
  }
}

class _FakeQueueRepository implements QueueRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [QueueController.toMedia] does not touch the player; avoid requiring libmpv
/// (missing on GitHub Actions `ubuntu-latest` validate runners).

void main() {
  late LocalAudioProxyServer proxy;
  late QueueController controller;

  setUp(() async {
    proxy = LocalAudioProxyServer(streamDatasource: _FakeStreamDatasource());
    await proxy.start();
    controller = QueueController(
      engine: FakePlaybackEngine(),
      queueRepo: _FakeQueueRepository(),
      getQueue: () => <MediaItem>[],
      getShuffleMode: () => AudioServiceShuffleMode.none,
      getRepeatMode: () => AudioServiceRepeatMode.none,
      updateQueueStream: (_) {},
      proxyServer: proxy,
    );
  });

  tearDown(() async {
    await proxy.stop();
  });

  test('toMedia prefers file:// over proxy when proxy is running', () {
    expect(proxy.isRunning, isTrue);
    const fileUrl = 'file:///data/vid1.mp3';
    final item =
        const QueueTrack(
          videoId: 'vid1',
          title: 'Local',
          artist: 'A',
          url: fileUrl,
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(media.uri.contains('/stream?videoId='), isFalse);
    expect(
      media.uri == fileUrl || media.uri == '/data/vid1.mp3',
      isTrue,
      reason: 'expected local file source, got ${media.uri}',
    );
  });

  test('toMedia uses proxy for remote URLs when proxy is running', () {
    expect(proxy.isRunning, isTrue);
    final item =
        const QueueTrack(
          videoId: 'vid2',
          title: 'Remote',
          artist: 'A',
          url: 'https://example.com/vid2.mp3',
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(
      media.uri,
      proxy.getStreamUrlForVideo('vid2', audioQuality: MediaQuality.high),
    );
  });

  test('toMedia uses audio proxy for catalog video tracks', () {
    controller.updateStreamPrefs(streamAudioQuality: MediaQuality.high);
    final item =
        const QueueTrack(
          videoId: 'vidVideo',
          title: 'Video',
          artist: 'A',
          isVideo: true,
          url: 'https://example.com/v.mp4',
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(
      media.uri,
      proxy.getStreamUrlForVideo('vidVideo', audioQuality: MediaQuality.high),
    );
    expect(media.uri, contains('qa=high'));
    expect(media.uri, isNot(contains('v=1')));
    expect(media.uri, isNot(contains('qv=')));
    expect(media.uri, isNot(contains('kind=')));
  });

  test('toMedia rejects muxed media-cache mp4 for catalog video tracks', () {
    const cacheUrl = 'file:///tmp/sonora_media_cache/vidVideo.mp4';
    final item =
        const QueueTrack(
          videoId: 'vidVideo',
          title: 'Video',
          artist: 'A',
          isVideo: true,
          url: cacheUrl,
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(media.uri, contains('/stream?videoId=vidVideo'));
    expect(media.uri, isNot(contains('v=1')));
  });

  test('toMedia keeps audio webm media-cache for catalog video tracks', () {
    const cacheUrl = 'file:///tmp/sonora_media_cache/vidVideo.webm';
    final item =
        const QueueTrack(
          videoId: 'vidVideo',
          title: 'Video',
          artist: 'A',
          isVideo: true,
          url: cacheUrl,
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(media.uri.contains('/stream?videoId='), isFalse);
    expect(
      media.uri == cacheUrl || media.uri.contains('sonora_media_cache'),
      isTrue,
    );
  });

  test('toMedia still uses media-cache file for audio-only', () {
    const cacheUrl = 'file:///tmp/sonora_media_cache/vid1.webm';
    final item =
        const QueueTrack(
          videoId: 'vid1',
          title: 'Song',
          artist: 'A',
          url: cacheUrl,
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(media.uri.contains('/stream?videoId='), isFalse);
  });

  test('toMedia rejects video-only cache without sibling audio', () {
    const cacheUrl = 'file:///tmp/sonora_media_cache/vidOrphan.v.mp4';
    final item =
        const QueueTrack(
          videoId: 'vidOrphan',
          title: 'Video',
          artist: 'A',
          isVideo: true,
          url: cacheUrl,
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(media.uri, contains('/stream?videoId=vidOrphan'));
    expect(media.uri, isNot(contains('v=1')));
  });

  test(
    'toMedia routes video-only cache pairs through the audio proxy',
    () async {
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/sonora_media_cache',
      );
      await cacheDir.create(recursive: true);
      final video = File('${cacheDir.path}/vidPair.v.mp4');
      final audio = File('${cacheDir.path}/vidPair.webm');
      await video.writeAsBytes(const [1, 2, 3]);
      await audio.writeAsBytes(const [4, 5, 6]);
      addTearDown(() async {
        if (await video.exists()) await video.delete();
        if (await audio.exists()) await audio.delete();
      });

      final item =
          QueueTrack(
            videoId: 'vidPair',
            title: 'Video',
            artist: 'A',
            isVideo: true,
            url: video.uri.toString(),
          ).toFreshMediaItem();

      final media = controller.toMedia(item);

      expect(media.uri, contains('/stream?videoId=vidPair'));
      expect(media.uri, isNot(contains('v=1')));
    },
  );

  test(
    'endResolving invokes onResolvingIdle only when nested count hits 0',
    () {
      var idleCalls = 0;
      final idleController = QueueController(
        engine: FakePlaybackEngine(),
        queueRepo: _FakeQueueRepository(),
        getQueue: () => <MediaItem>[],
        getShuffleMode: () => AudioServiceShuffleMode.none,
        getRepeatMode: () => AudioServiceRepeatMode.none,
        updateQueueStream: (_) {},
        onResolvingIdle: () => idleCalls++,
      );

      idleController.beginResolving();
      idleController.beginResolving();
      idleController.endResolving();
      expect(idleCalls, 0);
      idleController.endResolving();
      expect(idleCalls, 1);
    },
  );

  test('toMedia uses dummy URL when unresolved and proxy is off', () async {
    await proxy.stop();
    final item =
        const QueueTrack(
          videoId: 'vid3',
          title: 'Pending',
          needsUrl: true,
        ).toFreshMediaItem();

    final media = controller.toMedia(item);

    expect(media.uri, 'http://localhost/dummy_vid3.wav');
  });

  test('replaceAt swaps a slot without changing length or neighbors', () async {
    final engine = FakePlaybackEngine();
    final qc = QueueController(
      engine: engine,
      queueRepo: _FakeQueueRepository(),
      getQueue: () => <MediaItem>[],
      getShuffleMode: () => AudioServiceShuffleMode.none,
      getRepeatMode: () => AudioServiceRepeatMode.none,
      updateQueueStream: (_) {},
      proxyServer: proxy,
    );
    final items = [
      const QueueTrack(videoId: 'a', title: 'A').toFreshMediaItem(),
      const QueueTrack(
        videoId: 'b',
        title: 'B',
        needsUrl: true,
      ).toFreshMediaItem(),
      const QueueTrack(videoId: 'c', title: 'C').toFreshMediaItem(),
    ];
    await engine.open(items.map(qc.toMedia).toList());
    expect(engine.playlist.medias.length, 3);

    final updated =
        const QueueTrack(
          videoId: 'b',
          title: 'B',
          url: 'https://example.com/b.mp3',
        ).toFreshMediaItem();
    final written = await qc.replaceAt(1, qc.toMedia(updated));

    expect(written, 1);
    expect(engine.playlist.medias.length, 3);
    expect(engine.playlist.index, 0);
    expect(engine.playlist.medias[0].mediaItem?.title, 'A');
    expect(engine.playlist.medias[1].uri, contains('videoId=b'));
    expect(engine.playlist.medias[2].mediaItem?.title, 'C');
  });
}
