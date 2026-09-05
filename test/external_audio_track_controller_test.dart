import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/external_audio_track_controller.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';
import 'helpers/fake_playback_engine.dart';

void main() {
  late FakePlaybackEngine engine;
  late ExternalAudioTrackController controller;

  setUp(() {
    engine = FakePlaybackEngine();
    controller = ExternalAudioTrackController(engine: engine);
  });

  tearDown(() async {
    await engine.dispose();
  });

  test(
    'attaches sidecar uri when EngineMedia carries externalAudioUri',
    () async {
      const audioUri = 'file:///tmp/sonora_media_cache/vid.webm';
      final media = EngineMedia(
        uri: 'file:///tmp/sonora_media_cache/vid.v.mp4',
        externalAudioUri: audioUri,
      );

      await controller.attachForMedia(media);

      expect(engine.lastExternalAudioUri, audioUri);
    },
  );

  test('resets sidecar audio when extras have no external audio', () async {
    await controller.attachForMedia(
      const EngineMedia(uri: 'file:///tmp/sonora_media_cache/vid.mp4'),
    );

    expect(engine.lastExternalAudioUri, isNull);
  });

  test('resets to auto after skipping from a pair to an audio item', () async {
    await controller.attachForMedia(
      const EngineMedia(
        uri: 'file:///tmp/sonora_media_cache/vid.v.mp4',
        externalAudioUri: 'file:///tmp/sonora_media_cache/vid.webm',
      ),
    );
    await controller.attachForMedia(
      const EngineMedia(uri: 'file:///tmp/sonora_media_cache/song.webm'),
    );

    expect(engine.lastExternalAudioUri, isNull);
  });
}
