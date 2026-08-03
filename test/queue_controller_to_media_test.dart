import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/data/services/local_audio_proxy_server.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/domain/repositories/queue_repository.dart';
import 'package:sonora/presentation/features/player/queue_controller.dart';

class _FakeStreamDatasource extends StreamDatasource {
  @override
  Future<String> getStreamUrl(String videoId, {int attempt = 1}) async {
    return 'http://example.com/$videoId.mp3';
  }
}

class _FakeQueueRepository implements QueueRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Player player;
  late LocalAudioProxyServer proxy;
  late QueueController controller;

  setUpAll(() {
    MediaKit.ensureInitialized();
  });

  setUp(() async {
    player = Player();
    proxy = LocalAudioProxyServer(streamDatasource: _FakeStreamDatasource());
    await proxy.start();
    controller = QueueController(
      player: player,
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
    await player.dispose();
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

    // media_kit may normalize file:// to a bare path; either form is local.
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

    expect(media.uri, proxy.getStreamUrlForVideo('vid2'));
  });

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
}
