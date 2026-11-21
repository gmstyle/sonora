import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/presentation/features/player/play_error.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';
import 'package:sonora/presentation/features/player/playback_recovery_controller.dart';
import 'package:sonora/presentation/features/player/playback_state_publisher.dart';
import 'package:sonora/presentation/features/player/playback_volume_controller.dart';
import 'package:sonora/presentation/features/player/queue_controller.dart';
import 'package:sonora/presentation/features/player/track_url_resolver.dart';

import 'helpers/fake_playback_engine.dart';

class _FakePlayVideoIdUseCase extends Fake implements PlayVideoIdUseCase {}

class _FakeQueueController extends Fake implements QueueController {}

class _FakeVolumeController extends Fake implements PlaybackVolumeController {}

class _FakeStatePublisher extends Fake implements PlaybackStatePublisher {}

class _FakeUrlResolver extends Fake implements TrackUrlResolver {}

class _FakeConnectivity extends Fake implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

void main() {
  group('PlaybackRecoveryController.isLibraryDownloadTrack', () {
    test('accepts library file:// downloads', () {
      const track = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        url: 'file:///storage/Sonora/vid1.mp3',
      );
      expect(PlaybackRecoveryController.isLibraryDownloadTrack(track), isTrue);
    });

    test('rejects transparent media-cache URIs', () {
      const track = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        url: 'file:///tmp/sonora_media_cache/vid1.webm',
      );
      expect(PlaybackRecoveryController.isLibraryDownloadTrack(track), isFalse);
    });

    test('rejects remote / unresolved tracks', () {
      const remote = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        url: 'https://example.com/a.mp3',
      );
      const pending = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        needsUrl: true,
      );
      expect(
        PlaybackRecoveryController.isLibraryDownloadTrack(remote),
        isFalse,
      );
      expect(
        PlaybackRecoveryController.isLibraryDownloadTrack(pending),
        isFalse,
      );
    });
  });

  group('PlaybackRecoveryController.advancePastUnplayable', () {
    test(
      'resumes playback when skipping after an engine error pause',
      () async {
        final engine = FakePlaybackEngine(
          playing: false,
          playlist: EnginePlaylist(
            index: 0,
            medias: [
              EngineMedia(
                uri: 'https://example.com/bad',
                mediaItem: const QueueTrack(
                  videoId: 'bad',
                  title: 'Enough',
                  url: 'https://example.com/bad',
                ).toFreshMediaItem(),
              ),
              EngineMedia(
                uri: 'https://example.com/good',
                mediaItem: const QueueTrack(
                  videoId: 'good',
                  title: 'Next',
                  url: 'https://example.com/good',
                ).toFreshMediaItem(),
              ),
            ],
          ),
        );
        int? skippedTo;
        var playRequests = 0;

        final controller = PlaybackRecoveryController(
          engine: engine,
          playVideoIdUseCase: _FakePlayVideoIdUseCase(),
          queueController: _FakeQueueController(),
          volumeController: _FakeVolumeController(),
          statePublisher: _FakeStatePublisher(),
          urlResolver: _FakeUrlResolver(),
          connectivity: _FakeConnectivity(),
          userWantsPlaying: () => false,
          isStopping: () => false,
          requestPlay: () async => playRequests++,
          skipToQueueItem: (index) async {
            skippedTo = index;
            await engine.jump(index);
          },
          isCastConnected: () => false,
          setPausedForConnection: (_) {},
          castMedia: ({
            required String url,
            required String title,
            String? artist,
            String? album,
            String? artworkUrl,
          }) async {},
          waitForCastPlaying: () async {},
          castPause: () async {},
        );
        addTearDown(controller.dispose);

        final events = <PlayErrorEvent>[];
        final sub = controller.onPlayError.listen(events.add);
        addTearDown(sub.cancel);

        await controller.advancePastUnplayable(
          0,
          videoId: 'bad',
          title: 'Enough',
          kind: PlayErrorKind.unplayable,
        );
        await pumpEventQueue();
        await pumpEventQueue();

        expect(skippedTo, 1);
        expect(playRequests, 1);
        expect(events.single.skippedToNext, isTrue);
      },
    );
  });
}
