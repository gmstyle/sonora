import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Result of [StreamQualitySelector.selectPlayback].
class PlaybackSelection {
  /// Stream opened as the media_kit primary [Media] URI.
  final StreamInfo primary;

  /// Optional external audio for adaptive HD (`videoOnly` + `audioOnly`).
  /// Null means single-stream playback (audio-only or muxed).
  final StreamInfo? externalAudio;

  const PlaybackSelection({required this.primary, this.externalAudio});

  bool get isAdaptive => externalAudio != null;
}
