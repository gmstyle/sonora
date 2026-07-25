import 'package:audio_service/audio_service.dart';

/// Pure builder for notification / Android Auto media controls.
class PlayerMediaControls {
  static const String actionShuffle = 'shuffle';
  static const String actionRepeat = 'repeat';
  static const String actionLike = 'like';
  static const String actionStartRadio = 'start_radio';

  /// Builds the media-control row for the given [current] playback state.
  static List<MediaControl> build(
    PlaybackState current, {
    required bool isLiked,
  }) {
    final shuffleIcon =
        current.shuffleMode == AudioServiceShuffleMode.all
            ? 'drawable/ic_shuffle'
            : 'drawable/ic_shuffle_off';

    final repeatIcon = switch (current.repeatMode) {
      AudioServiceRepeatMode.one => 'drawable/ic_repeat_one',
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => 'drawable/ic_repeat',
      _ => 'drawable/ic_repeat_off',
    };

    return [
      MediaControl.skipToPrevious,
      if (current.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.custom(
        androidIcon: shuffleIcon,
        label:
            current.shuffleMode == AudioServiceShuffleMode.all
                ? 'Shuffle On'
                : 'Shuffle',
        name: actionShuffle,
      ),
      MediaControl.custom(
        androidIcon: repeatIcon,
        label: switch (current.repeatMode) {
          AudioServiceRepeatMode.one => 'Repeat One',
          AudioServiceRepeatMode.all => 'Repeat All',
          _ => 'Repeat',
        },
        name: actionRepeat,
      ),
      MediaControl.custom(
        androidIcon:
            isLiked ? 'drawable/ic_favorite' : 'drawable/ic_favorite_border',
        label: isLiked ? 'Unlike' : 'Like',
        name: actionLike,
      ),
      MediaControl.custom(
        androidIcon: 'drawable/ic_radio',
        label: 'Start Radio',
        name: actionStartRadio,
      ),
    ];
  }
}
