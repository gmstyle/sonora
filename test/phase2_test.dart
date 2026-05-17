import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  group('SettingsNotifier', () {
    test('initial state has default crossfade and restore-queue', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final settings = container.read(settingsProvider);
      expect(settings.crossfadeDuration, const Duration(seconds: 2));
      expect(settings.restoreQueueOnStartup, true);
    });

    test('setCrossfadeSeconds updates the value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      await container.read(settingsProvider.notifier).setCrossfadeSeconds(5);
      final settings = container.read(settingsProvider);
      expect(settings.crossfadeDuration, const Duration(seconds: 5));
    });

    test('setRestoreQueueOnStartup updates the value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      await container
          .read(settingsProvider.notifier)
          .setRestoreQueueOnStartup(false);
      final settings = container.read(settingsProvider);
      expect(settings.restoreQueueOnStartup, false);
    });

    test('crossfade settings', () {
      const settings = Settings(crossfadeSeconds: 15);
      expect(settings.crossfadeDuration, const Duration(seconds: 15));
      const zero = Settings(crossfadeSeconds: 0);
      expect(zero.crossfadeDuration, Duration.zero);
    });
  });

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
