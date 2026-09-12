import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/audio_session_controller.dart';

void main() {
  group('AudioSessionController', () {
    late bool userWantsPlaying;
    late bool isRemotePlaying;
    late bool isRemotePlayback;
    late int pauseCount;
    late int resumeCount;
    late AudioSessionController controller;

    setUp(() {
      userWantsPlaying = true;
      isRemotePlaying = true;
      isRemotePlayback = false;
      pauseCount = 0;
      resumeCount = 0;
      controller = AudioSessionController(
        userWantsPlaying: () => userWantsPlaying,
        isRemotePlaying: () => isRemotePlaying,
        isRemotePlayback: () => isRemotePlayback,
        onPauseRequested: () => pauseCount++,
        onResumeRequested: () => resumeCount++,
      );
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
      isRemotePlayback = true;
      controller.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(pauseCount, 1);

      isRemotePlaying = false;
      userWantsPlaying = false;
      controller.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(resumeCount, 1);
    });

    test('does not auto-resume Cast if it was already paused', () {
      isRemotePlayback = true;
      userWantsPlaying = false;
      isRemotePlaying = false;
      controller.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      controller.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(resumeCount, 0);
    });

    test('does not duck — just_audio / Android handle music ducking', () {
      isRemotePlayback = true;
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
