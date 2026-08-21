import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sonora/presentation/features/player/external_audio_track_controller.dart';

class _FakePlayer extends Fake implements Player {
  final List<AudioTrack> tracks = [];

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    tracks.add(track);
  }
}

void main() {
  late _FakePlayer player;
  late ExternalAudioTrackController controller;

  setUp(() {
    player = _FakePlayer();
    controller = ExternalAudioTrackController(player: player);
  });

  test('attaches AudioTrack.uri when extras carry externalAudioUri', () async {
    const audioUri = 'file:///tmp/sonora_media_cache/vid.webm';
    final media = Media(
      'file:///tmp/sonora_media_cache/vid.v.mp4',
      extras: {ExternalAudioTrackController.extraKey: audioUri},
    );

    await controller.attachForMedia(media);

    expect(player.tracks, hasLength(1));
    expect(player.tracks.single.uri, isTrue);
    expect(player.tracks.single.id, audioUri);
  });

  test(
    'resets to AudioTrack.auto when extras have no external audio',
    () async {
      await controller.attachForMedia(
        Media('file:///tmp/sonora_media_cache/vid.mp4'),
      );

      expect(player.tracks, hasLength(1));
      expect(player.tracks.single.uri, isFalse);
      expect(player.tracks.single.id, 'auto');
    },
  );

  test('resets to auto after skipping from a pair to an audio item', () async {
    await controller.attachForMedia(
      Media(
        'file:///tmp/sonora_media_cache/vid.v.mp4',
        extras: {
          ExternalAudioTrackController.extraKey:
              'file:///tmp/sonora_media_cache/vid.webm',
        },
      ),
    );
    await controller.attachForMedia(
      Media('file:///tmp/sonora_media_cache/song.webm'),
    );

    expect(player.tracks, hasLength(2));
    expect(player.tracks.last.id, 'auto');
    expect(player.tracks.last.uri, isFalse);
  });
}
