import 'package:audio_session/audio_session.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/presentation/features/player/cast_playback_controller.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';
import 'package:sonora/presentation/features/player/playback_volume_controller.dart';

class _FakeEngine extends Fake implements PlaybackEngine {}

class _FakeVolume extends Fake implements PlaybackVolumeController {}

class _FakePlayVideoId extends Fake implements PlayVideoIdUseCase {}

void main() {
  group('CastPlaybackController audio interruptions', () {
    late bool userWantsPlaying;
    late int pauseCount;
    late int resumeCount;
    late CastPlaybackController controller;

    setUp(() {
      userWantsPlaying = true;
      pauseCount = 0;
      resumeCount = 0;
      controller = CastPlaybackController(
        engine: _FakeEngine(),
        volumeController: _FakeVolume(),
        playVideoIdUseCase: _FakePlayVideoId(),
        userWantsPlaying: () => userWantsPlaying,
        currentMediaItem: () => null,
        lanCastUrl: (_) async => null,
      );
      controller.onInterruptionPause = () => pauseCount++;
      controller.onInterruptionResume = () => resumeCount++;
    });

    test('ignores local interruptions — just_audio owns that path', () {
      controller.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      controller.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(pauseCount, 0);
      expect(resumeCount, 0);
    });

    test('pauses and resumes Cast when a phone call starts and ends', () {
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.playing,
      );
      controller.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(pauseCount, 1);

      userWantsPlaying = false;
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.paused,
      );
      controller.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(resumeCount, 1);
    });

    test('does not auto-resume Cast if it was already paused', () {
      userWantsPlaying = false;
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.paused,
      );
      controller.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      controller.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(resumeCount, 0);
    });

    test('does not duck — just_audio / Android handle music ducking', () {
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.playing,
      );
      controller.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      controller.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(pauseCount, 0);
      expect(resumeCount, 0);
    });
  });
}
