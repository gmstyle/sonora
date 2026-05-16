import 'package:flutter_riverpod/flutter_riverpod.dart';

class Settings {
  final Duration crossfadeDuration;
  final bool restoreQueueOnStartup;
  final bool trackHistory;

  const Settings({
    this.crossfadeDuration = const Duration(seconds: 2),
    this.restoreQueueOnStartup = true,
    this.trackHistory = true,
  });

  Settings copyWith({
    Duration? crossfadeDuration,
    bool? restoreQueueOnStartup,
    bool? trackHistory,
  }) {
    return Settings(
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      restoreQueueOnStartup: restoreQueueOnStartup ?? this.restoreQueueOnStartup,
      trackHistory: trackHistory ?? this.trackHistory,
    );
  }
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => const Settings();

  void setCrossfadeDuration(Duration duration) {
    state = state.copyWith(crossfadeDuration: duration);
  }

  void setRestoreQueueOnStartup(bool value) {
    state = state.copyWith(restoreQueueOnStartup: value);
  }

  void setTrackHistory(bool value) {
    state = state.copyWith(trackHistory: value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
