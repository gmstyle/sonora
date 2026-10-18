/// Thrown when Sonora refuses a YouTube stream/manifest request because a
/// recent HTTP 429 tripped the cool-down circuit.
///
/// Prefer failing fast over retrying: additional watch/player calls while the
/// IP is limited extend the block.
class YoutubeRateLimitedException implements Exception {
  /// Remaining cool-down when the exception was created.
  final Duration retryAfter;

  const YoutubeRateLimitedException(this.retryAfter);

  @override
  String toString() =>
      'YoutubeRateLimitedException: YouTube rate-limit cool-down '
      '(${retryAfter.inSeconds}s remaining). '
      'Wait before resolving more stream URLs.';
}
