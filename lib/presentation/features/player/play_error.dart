import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Why a queue track failed to play.
enum PlayErrorKind {
  /// Permanently unavailable (age-gate, geo, removed, etc.).
  unplayable,

  /// Transient connectivity / timeout failure.
  network,

  /// Unclassified failure.
  unknown;

  static PlayErrorKind classify(Object error) {
    if (error is VideoUnplayableException ||
        error is VideoUnavailableException) {
      return PlayErrorKind.unplayable;
    }
    final s = error.toString().toLowerCase();
    if (s.contains('videounplayable') ||
        s.contains('videounavailable') ||
        s.contains('unplayable') ||
        s.contains('sign in to confirm your age')) {
      return PlayErrorKind.unplayable;
    }
    if (s.contains('socketexception') ||
        s.contains('timeout') ||
        s.contains('network') ||
        s.contains('connection failed') ||
        s.contains('handshakeexception') ||
        s.contains('failed to host') ||
        s.contains('connection timed out') ||
        s.contains('offline')) {
      return PlayErrorKind.network;
    }
    return PlayErrorKind.unknown;
  }
}

/// Event emitted on the player error stream for UI toast + queue marking.
class PlayErrorEvent {
  final String videoId;
  final String title;
  final PlayErrorKind kind;

  /// True when recovery advanced to a later playable queue item.
  final bool skippedToNext;

  const PlayErrorEvent({
    required this.videoId,
    required this.title,
    required this.kind,
    this.skippedToNext = false,
  });
}
