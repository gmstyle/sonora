import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

/// Songs YouTube Music did not grey out (`SongDetailed.isPlayable`).
List<SongDetailed> playableSongs(Iterable<SongDetailed> songs) => [
  for (final s in songs)
    if (s.isPlayable) s,
];

/// Videos YouTube Music did not grey out (`VideoDetailed.isPlayable`).
List<VideoDetailed> playableVideos(Iterable<VideoDetailed> videos) => [
  for (final v in videos)
    if (v.isPlayable) v,
];

/// Maps an index in [original] onto [playable].
///
/// If [originalIndex] points at a playable row, returns its index in
/// [playable]. Otherwise returns the next playable after that index, or `0`
/// when none remain after it (falls back to the first playable).
int playableLeadIndex<T extends Object>(
  List<T> original,
  int originalIndex, {
  required List<T> playable,
  bool Function(T item)? isPlayable,
}) {
  if (playable.isEmpty) return 0;
  final check =
      isPlayable ??
      (T item) {
        if (item is SongDetailed) return item.isPlayable;
        if (item is VideoDetailed) return item.isPlayable;
        return true;
      };

  if (originalIndex >= 0 && originalIndex < original.length) {
    final start = original[originalIndex];
    if (check(start)) {
      final mapped = playable.indexOf(start);
      if (mapped >= 0) return mapped;
    }
    for (var i = originalIndex + 1; i < original.length; i++) {
      final candidate = original[i];
      if (!check(candidate)) continue;
      final mapped = playable.indexOf(candidate);
      if (mapped >= 0) return mapped;
    }
  }
  return 0;
}

/// Sum of playable track durations (seconds).
Duration playableDuration(Iterable<SongDetailed> songs) {
  var total = Duration.zero;
  for (final s in songs) {
    if (!s.isPlayable) continue;
    total += Duration(seconds: s.duration ?? 0);
  }
  return total;
}

Duration playableVideoDuration(Iterable<VideoDetailed> videos) {
  var total = Duration.zero;
  for (final v in videos) {
    if (!v.isPlayable) continue;
    total += Duration(seconds: v.duration ?? 0);
  }
  return total;
}

int unplayableSongCount(Iterable<SongDetailed> songs) =>
    songs.where((s) => !s.isPlayable).length;

int unplayableVideoCount(Iterable<VideoDetailed> videos) =>
    videos.where((v) => !v.isPlayable).length;
