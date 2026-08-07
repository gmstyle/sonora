import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_quality.dart';

/// Picks a single [StreamInfo] from a [StreamManifest] for the given quality
/// tier and whether video is required.
///
/// When [preferVideo] is true, prefers muxed streams (A+V, max ~360p).
/// Otherwise prefers audio-only streams. Falls back to the other family if the
/// preferred list is empty.
class StreamQualitySelector {
  const StreamQualitySelector();

  /// Selects a stream matching [quality] / [preferVideo].
  ///
  /// Throws [StateError] if the manifest has no usable streams.
  StreamInfo select(
    StreamManifest manifest, {
    required MediaQuality quality,
    required bool preferVideo,
  }) {
    final primary =
        preferVideo
            ? _pickMuxed(manifest.muxed, quality)
            : _pickByBitrate(manifest.audioOnly, quality);

    if (primary != null) return primary;

    final fallback =
        preferVideo
            ? _pickByBitrate(manifest.audioOnly, quality)
            : _pickMuxed(manifest.muxed, quality);

    if (fallback != null) return fallback;

    throw StateError('No streams available in manifest');
  }

  /// Picks from a bitrate-sorted list (highest first).
  static T? _pickByBitrate<T extends StreamInfo>(
    Iterable<T> streams,
    MediaQuality quality,
  ) {
    final sorted = streams.sortByBitrate();
    if (sorted.isEmpty) return null;
    return _pickTier(sorted, quality);
  }

  /// Picks a muxed stream by video quality label where possible, else bitrate.
  static MuxedStreamInfo? _pickMuxed(
    Iterable<MuxedStreamInfo> streams,
    MediaQuality quality,
  ) {
    final list = streams.toList();
    if (list.isEmpty) return null;

    switch (quality) {
      case MediaQuality.high:
        return list.withHighestBitrate();
      case MediaQuality.mid:
        final mid = list.where((s) => s.videoQuality == VideoQuality.medium360);
        if (mid.isNotEmpty) return mid.withHighestBitrate();
        return _pickByBitrate(list, MediaQuality.mid);
      case MediaQuality.low:
        final low = list.where(
          (s) =>
              s.videoQuality == VideoQuality.low240 ||
              s.videoQuality == VideoQuality.low144,
        );
        if (low.isNotEmpty) return low.sortByBitrate().last;
        return _pickByBitrate(list, MediaQuality.low);
    }
  }

  /// [sorted] must be highest-bitrate-first (as from [sortByBitrate]).
  static T _pickTier<T>(List<T> sorted, MediaQuality quality) {
    assert(sorted.isNotEmpty);
    return switch (quality) {
      MediaQuality.high => sorted.first,
      MediaQuality.mid => sorted[sorted.length ~/ 2],
      MediaQuality.low => sorted.last,
    };
  }
}
