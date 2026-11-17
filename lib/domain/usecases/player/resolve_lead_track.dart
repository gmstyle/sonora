import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../../core/errors/youtube_rate_limited_exception.dart';
import '../../../core/utils/playable_tracks.dart';

/// Result of resolving the initial playable track in an album or playlist.
typedef ResolvedLeadResult<T> = ({List<T> tracks, int leadIndex, String url});

/// Builds a [List<MediaItem>] queue from [items], keeping only [playable] rows
/// and resolving the stream URL for the lead track at [playIndex] (or skipping
/// resolution when [playIndex] < 0).
Future<List<MediaItem>> buildPlayableQueue<T extends Object>(
  List<T> items, {
  required List<T> playable,
  required int playIndex,
  required String Function(T item) videoIdOf,
  required Future<String> Function(String videoId) resolveUrl,
  required MediaItem Function(T item, String? url) toMediaItem,
  void Function(int index)? onResolvedLeadIndex,
}) async {
  if (playable.isEmpty) return [];
  if (playIndex < 0) {
    return [for (final item in playable) toMediaItem(item, null)];
  }

  final initialLead = playableLeadIndex(items, playIndex, playable: playable);
  final resolved = await resolveLeadTrack(
    playable,
    initialLead,
    videoIdOf: videoIdOf,
    resolveUrl: resolveUrl,
  );
  onResolvedLeadIndex?.call(resolved.leadIndex);

  return [
    for (int i = 0; i < resolved.tracks.length; i++)
      toMediaItem(
        resolved.tracks[i],
        i == resolved.leadIndex ? resolved.url : null,
      ),
  ];
}

/// Resolves the stream URL for the lead track at [leadIndex] in [playable],
/// advancing to subsequent playable tracks when a single track fails stream
/// resolution (e.g. geo-blocked, removed, or age-restricted).
///
/// Tracks that fail resolution are omitted from the returned [tracks] list and
/// [leadIndex] is adjusted accordingly. Global failures (offline, timeouts,
/// rate limits) are rethrown immediately without probing further tracks.
Future<ResolvedLeadResult<T>> resolveLeadTrack<T>(
  List<T> playable,
  int leadIndex, {
  required String Function(T item) videoIdOf,
  required Future<String> Function(String videoId) resolveUrl,
  int maxSkipAttempts = 5,
}) async {
  final safeLead = leadIndex.clamp(0, playable.length - 1);
  final candidates = <int>[
    for (int i = safeLead; i < playable.length; i++) i,
    for (int i = 0; i < safeLead; i++) i,
  ];

  final skippedIndices = <int>{};
  Object? lastError;
  StackTrace? lastStackTrace;
  var attempts = 0;

  for (final idx in candidates) {
    if (attempts >= maxSkipAttempts) break;
    attempts++;

    try {
      final url = await resolveUrl(videoIdOf(playable[idx]));
      final filtered = <T>[];
      var resolvedLead = 0;
      for (int i = 0; i < playable.length; i++) {
        if (skippedIndices.contains(i)) continue;
        if (i == idx) resolvedLead = filtered.length;
        filtered.add(playable[i]);
      }
      return (tracks: filtered, leadIndex: resolvedLead, url: url);
    } catch (e, st) {
      if (_shouldAbortImmediately(e)) rethrow;
      skippedIndices.add(idx);
      lastError = e;
      lastStackTrace = st;
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }
  throw StateError('No playable tracks available');
}

bool _shouldAbortImmediately(Object error) {
  if (error is YoutubeRateLimitedException ||
      error is RequestLimitExceededException ||
      error is SocketException ||
      error is TimeoutException) {
    return true;
  }
  final s = error.toString().toLowerCase();
  return s.contains('youtuberatelimited') ||
      s.contains('requestlimitexceeded') ||
      s.contains('rate limit') ||
      s.contains('rate-limit') ||
      s.contains('rate_limit') ||
      s.contains('cool-down') ||
      s.contains('cooldown') ||
      s.contains('socketexception') ||
      s.contains('timeout') ||
      s.contains('network') ||
      s.contains('connection failed') ||
      s.contains('handshakeexception') ||
      s.contains('failed to host') ||
      s.contains('connection timed out') ||
      s.contains('connessione scaduta') ||
      s.contains('offline');
}
