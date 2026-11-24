import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Pure builder for notification / Android Auto media controls.
class PlayerMediaControls {
  static const String actionShuffle = 'shuffle';
  static const String actionRepeat = 'repeat';
  static const String actionLike = 'like';
  static const String actionStartRadio = 'start_radio';
  static const String actionRewind10 = 'rewind_10';
  static const String actionForward30 = 'forward_30';
  static const String actionCycleSpeed = 'cycle_speed';

  static const List<double> podcastSpeedSteps = [1.0, 1.25, 1.5, 2.0];

  static double nextPodcastSpeed(double currentSpeed) {
    for (final step in podcastSpeedSteps) {
      if (step > currentSpeed + 0.05) return step;
    }
    return podcastSpeedSteps.first;
  }

  static String formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return speed.toInt().toString();
    }
    return speed.toString();
  }

  static AppLocalizations resolveL10n([AppLocalizations? override]) {
    if (override != null) return override;
    try {
      return lookupAppLocalizations(PlatformDispatcher.instance.locale);
    } catch (_) {
      return AppLocalizationsEn();
    }
  }

  /// Builds the media-control row for the given [current] playback state.
  static List<MediaControl> build(
    PlaybackState current, {
    required bool isLiked,
    bool isEpisode = false,
    bool isOffline = false,
    double speed = 1.0,
    AppLocalizations? l10n,
  }) {
    final tr = resolveL10n(l10n);

    final base = <MediaControl>[
      MediaControl.skipToPrevious,
      if (current.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ];

    if (isEpisode) {
      return [
        ...base,
        MediaControl.custom(
          androidIcon: 'drawable/ic_replay_10',
          label: tr.aaRewind10,
          name: actionRewind10,
        ),
        MediaControl.custom(
          androidIcon: 'drawable/ic_forward_30',
          label: tr.aaForward30,
          name: actionForward30,
        ),
        MediaControl.custom(
          androidIcon: isLiked
              ? 'drawable/ic_bookmark'
              : 'drawable/ic_bookmark_border',
          label: isLiked ? tr.aaUnsaveEpisode : tr.aaSaveEpisode,
          name: actionLike,
        ),
        MediaControl.custom(
          androidIcon: 'drawable/ic_speed',
          label: tr.aaPlaybackSpeed(formatSpeed(speed)),
          name: actionCycleSpeed,
        ),
      ];
    }

    final shuffleIcon = current.shuffleMode == AudioServiceShuffleMode.all
        ? 'drawable/ic_shuffle'
        : 'drawable/ic_shuffle_off';

    final repeatIcon = switch (current.repeatMode) {
      AudioServiceRepeatMode.one => 'drawable/ic_repeat_one',
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => 'drawable/ic_repeat',
      _ => 'drawable/ic_repeat_off',
    };

    return [
      ...base,
      MediaControl.custom(
        androidIcon: shuffleIcon,
        label: current.shuffleMode == AudioServiceShuffleMode.all
            ? tr.aaShuffleOn
            : tr.shuffle,
        name: actionShuffle,
      ),
      MediaControl.custom(
        androidIcon: repeatIcon,
        label: switch (current.repeatMode) {
          AudioServiceRepeatMode.one => tr.aaRepeatOne,
          AudioServiceRepeatMode.all ||
          AudioServiceRepeatMode.group => tr.aaRepeatAll,
          _ => tr.repeatOff,
        },
        name: actionRepeat,
      ),
      MediaControl.custom(
        androidIcon: isLiked
            ? 'drawable/ic_favorite'
            : 'drawable/ic_favorite_border',
        label: isLiked ? tr.aaUnlike : tr.aaLike,
        name: actionLike,
      ),
      if (!isOffline)
        MediaControl.custom(
          androidIcon: 'drawable/ic_radio',
          label: tr.aaStartRadio,
          name: actionStartRadio,
        ),
    ];
  }
}
