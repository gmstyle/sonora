import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_quality.dart';
import '../models/playback_selection.dart';

/// Picks streams from a [StreamManifest] for playback / download quality tiers.
///
/// Single-URL path ([select]): muxed when video is preferred (≤~360p), otherwise
/// audio-only.
///
/// Playback path ([selectPlayback]): when video is preferred, prefers an
/// adaptive `videoOnly` + `audioOnly` pair (HD); falls back to muxed.
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

  /// Selects primary (+ optional external audio) for local playback.
  ///
  /// When [preferVideo] is true and both `videoOnly` and `audioOnly` exist,
  /// returns an adaptive pair using [videoQuality] / [audioQuality].
  /// Otherwise falls back to [select] (muxed uses [videoQuality] when
  /// preferring video; audio-only uses [audioQuality]).
  PlaybackSelection selectPlayback(
    StreamManifest manifest, {
    required MediaQuality audioQuality,
    required MediaQuality videoQuality,
    required bool preferVideo,
  }) {
    if (preferVideo) {
      final video = _pickVideoOnly(manifest.videoOnly, videoQuality);
      final audio = _pickByBitrate(manifest.audioOnly, audioQuality);
      if (video != null && audio != null) {
        return PlaybackSelection(primary: video, externalAudio: audio);
      }
      return PlaybackSelection(
        primary: select(manifest, quality: videoQuality, preferVideo: true),
      );
    }

    return PlaybackSelection(
      primary: select(manifest, quality: audioQuality, preferVideo: false),
    );
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

  /// Picks video-only by resolution tier (capped at 1080p for high).
  static VideoOnlyStreamInfo? _pickVideoOnly(
    Iterable<VideoOnlyStreamInfo> streams,
    MediaQuality quality,
  ) {
    final list =
        streams.where((s) => s.videoQuality != VideoQuality.unknown).toList();
    if (list.isEmpty) return null;

    final VideoQuality maxQuality;
    final VideoQuality? preferred;
    switch (quality) {
      case MediaQuality.high:
        maxQuality = VideoQuality.high1080;
        preferred = null;
      case MediaQuality.mid:
        maxQuality = VideoQuality.high720;
        preferred = VideoQuality.high720;
      case MediaQuality.low:
        maxQuality = VideoQuality.medium360;
        preferred = VideoQuality.medium360;
    }

    final capped =
        list.where((s) => s.videoQuality.index <= maxQuality.index).toList();
    final pool = capped.isNotEmpty ? capped : list;

    if (preferred != null) {
      final exact = pool.where((s) => s.videoQuality == preferred).toList();
      if (exact.isNotEmpty) return exact.sortByVideoQuality().first;
    }

    return pool.sortByVideoQuality().first;
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
