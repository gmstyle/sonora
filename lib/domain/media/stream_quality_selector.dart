import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_quality.dart';

/// Picks an audio stream from a [StreamManifest] for playback / download.
///
/// Prefers [StreamManifest.audioOnly] tiered by [quality]. Falls back to the
/// best muxed stream when audio-only is empty.
class StreamQualitySelector {
  const StreamQualitySelector();

  /// Selects a stream matching [quality].
  ///
  /// Throws [StateError] if the manifest has no usable streams.
  StreamInfo select(StreamManifest manifest, {required MediaQuality quality}) {
    final primary = _pickByBitrate(manifest.audioOnly, quality);
    if (primary != null) return primary;

    final fallback = _pickBestMuxed(manifest.muxed);
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

  /// Best available muxed stream (highest bitrate).
  static MuxedStreamInfo? _pickBestMuxed(Iterable<MuxedStreamInfo> streams) {
    final list = streams.toList();
    if (list.isEmpty) return null;
    return list.withHighestBitrate();
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
