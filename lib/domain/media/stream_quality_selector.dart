import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_quality.dart';

/// Picks streams from a [StreamManifest] for playback / download.
///
/// When [preferVideo] is true: best-bitrate muxed (quality ignored).
/// When false: audio-only tiered by [quality].
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
            ? _pickBestMuxed(manifest.muxed)
            : _pickByBitrate(manifest.audioOnly, quality);

    if (primary != null) return primary;

    final fallback =
        preferVideo
            ? _pickByBitrate(manifest.audioOnly, quality)
            : _pickBestMuxed(manifest.muxed);

    if (fallback != null) return fallback;

    throw StateError('No streams available in manifest');
  }

  /// Progressive adaptive pair for disk-caching video when no muxed stream
  /// exists (common after visionos-only manifests). Caps video at 720p to
  /// keep the lookahead cache bounded.
  ({VideoOnlyStreamInfo video, AudioOnlyStreamInfo audio})?
  selectAdaptiveCachePair(
    StreamManifest manifest, {
    required MediaQuality audioQuality,
  }) {
    final video = _pickVideoForCache(manifest.videoOnly);
    final audio = _pickByBitrate(manifest.audioOnly, audioQuality);
    if (video == null || audio == null) return null;
    return (video: video, audio: audio);
  }

  /// Progressive video-only, preferring mp4 ≤720p.
  static VideoOnlyStreamInfo? _pickVideoForCache(
    Iterable<VideoOnlyStreamInfo> streams,
  ) {
    final pool = streams.toList();
    if (pool.isEmpty) return null;

    final mp4 =
        pool.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
    final preferred = mp4.isNotEmpty ? mp4 : pool;
    final capped =
        preferred
            .where(
              (s) =>
                  s.videoResolution.height > 0 &&
                  s.videoResolution.height <= 720,
            )
            .toList();
    final use = capped.isNotEmpty ? capped : preferred;
    return use.withHighestBitrate();
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
