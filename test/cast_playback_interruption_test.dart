import 'package:audio_session/audio_session.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/presentation/features/player/cast_playback_controller.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';
import 'package:sonora/presentation/features/player/playback_volume_controller.dart';

class _FakeEngine extends Fake implements PlaybackEngine {
  @override
  PlaybackEngineState get state => const PlaybackEngineState();
}

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

  group('CastPlaybackController remote track end', () {
    late bool userWantsPlaying;
    late int endedCount;
    late CastPlaybackController controller;

    setUp(() {
      userWantsPlaying = true;
      endedCount = 0;
      controller = CastPlaybackController(
        engine: _FakeEngine(),
        volumeController: _FakeVolume(),
        playVideoIdUseCase: _FakePlayVideoId(),
        userWantsPlaying: () => userWantsPlaying,
        currentMediaItem: () => null,
        lanCastUrl: (_) async => null,
      );
      controller.onRemoteTrackEnded = () => endedCount++;
    });

    test('playing then idle advances the queue', () {
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.playing,
      );
      controller.handleRemoteSessionState(SessionState.idle);
      expect(endedCount, 1);
    });

    test('loading then idle does not advance (load handshake)', () {
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.loading,
      );
      controller.handleRemoteSessionState(SessionState.idle);
      expect(endedCount, 0);
    });

    test('playing then idle is ignored when the user paused', () {
      userWantsPlaying = false;
      controller.debugSetRemotePlayback(
        connected: true,
        remoteState: SessionState.playing,
      );
      controller.handleRemoteSessionState(SessionState.idle);
      expect(endedCount, 0);
    });
  });
}
