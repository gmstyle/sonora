/// Which URL to resolve from a [PlaybackSelection] / stream cache entry.
enum StreamRole {
  /// Default single-URL path (audio-only or muxed, depending on preferVideo).
  primary,

  /// Video-only (adaptive) or muxed fallback when preferVideo.
  video,

  /// External audio track for adaptive HD playback.
  audio,
}
