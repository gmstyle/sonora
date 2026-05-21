import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/providers/player_provider.dart';

void main() {
  group('PlayerState', () {
    test('initial state has defaults', () {
      const state = PlayerState();
      expect(state.isPlaying, false);
      expect(state.isLoading, false);
      expect(state.isPaused, false);
      expect(state.hasError, false);
      expect(state.currentSong, isNull);
      expect(state.queue, isEmpty);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.shuffleMode, AudioServiceShuffleMode.none);
      expect(state.repeatMode, AudioServiceRepeatMode.none);
      expect(state.sleepTimerRemaining, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const state = PlayerState(isPlaying: true);
      final updated = state.copyWith(isPaused: true);
      expect(updated.isPlaying, true);
      expect(updated.isPaused, true);
      expect(updated.hasError, false);
    });

    test('copyWith clearError clears error message', () {
      const state = PlayerState(hasError: true, errorMessage: 'oops');
      final updated = state.copyWith(clearError: true);
      expect(updated.hasError, true);
      expect(updated.errorMessage, isNull);
    });

    test('copyWith clearSleepTimer clears sleep timer', () {
      const state = PlayerState(sleepTimerRemaining: Duration(minutes: 5));
      final updated = state.copyWith(clearSleepTimer: true);
      expect(updated.sleepTimerRemaining, isNull);
    });

    test('copyWith overwrites specified fields', () {
      const state = PlayerState();
      final updated = state.copyWith(
        isPlaying: true,
        isLoading: true,
        currentSong: MediaItem(id: '1', title: 'Test'),
        queue: [MediaItem(id: '1', title: 'Test')],
        position: Duration(seconds: 30),
        duration: Duration(seconds: 200),
        shuffleMode: AudioServiceShuffleMode.all,
        repeatMode: AudioServiceRepeatMode.one,
        sleepTimerRemaining: Duration(minutes: 10),
      );
      expect(updated.isPlaying, true);
      expect(updated.isLoading, true);
      expect(updated.currentSong?.id, '1');
      expect(updated.queue.length, 1);
      expect(updated.position, Duration(seconds: 30));
      expect(updated.duration, Duration(seconds: 200));
      expect(updated.shuffleMode, AudioServiceShuffleMode.all);
      expect(updated.repeatMode, AudioServiceRepeatMode.one);
      expect(updated.sleepTimerRemaining, Duration(minutes: 10));
    });
  });
}
