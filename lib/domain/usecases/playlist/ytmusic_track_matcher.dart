import '../../models/playlist_import.dart';

/// Picks the best YouTube Music search hit for a Spotify track.
class YtMusicTrackMatcher {
  const YtMusicTrackMatcher();

  static const minScore = 0.55;

  ImportedTrackCandidate? pickBest({
    required SpotifyPlaylistTrack track,
    required List<ImportedTrackCandidate> candidates,
  }) {
    ImportedTrackCandidate? best;
    var bestScore = 0.0;

    for (final candidate in candidates) {
      if (candidate.videoId.isEmpty) continue;
      final score = scoreCandidate(track, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    if (best == null || bestScore < minScore) return null;
    return best;
  }

  /// Search strings to try, in order (title+artist, then a cleaned title).
  List<String> searchQueries(SpotifyPlaylistTrack track) {
    final title = track.title.trim();
    final artist = track.primaryArtist;
    final stripped = stripDecorations(title);
    final queries = <String>[];

    if (artist.isNotEmpty) {
      queries.add('$title $artist');
      if (stripped != title) {
        queries.add('$stripped $artist');
      }
    } else {
      queries.add(title);
      if (stripped != title) queries.add(stripped);
    }

    return queries.toSet().toList(growable: false);
  }

  double scoreCandidate(
    SpotifyPlaylistTrack track,
    ImportedTrackCandidate candidate,
  ) {
    final titleScore = _similarity(
      normalize(track.title),
      normalize(candidate.title),
    );
    if (titleScore < 0.4) return 0;

    final artistScore = _artistScore(track, candidate);
    final durationScore = _durationScore(
      track.durationMs,
      candidate.durationSec,
    );

    if (track.artistNames.isNotEmpty &&
        artistScore < 0.35 &&
        durationScore < 0.85) {
      return 0;
    }

    return titleScore * 0.6 + artistScore * 0.3 + durationScore * 0.1;
  }

  static String stripDecorations(String title) {
    var value = title.replaceAll('\u00a0', ' ');
    value = value.replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*(feat\.?|ft\.?|featuring)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(
        r'\s*[-–—]\s*(re-?master(?:ed)?(?:\s+\d{4})?|radio edit|acoustic(?: version)?|remix).*$',
        caseSensitive: false,
      ),
      '',
    );
    return value.trim();
  }

  static String normalize(String input) {
    var value = stripDecorations(input).toLowerCase().replaceAll('\u00a0', ' ');
    value = value.replaceAll(RegExp(r"['’`]"), '');
    value = value.replaceAll(RegExp(r'[^a-z0-9&]+'), ' ');
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _artistScore(
    SpotifyPlaylistTrack track,
    ImportedTrackCandidate candidate,
  ) {
    final names = track.artistNames;
    if (names.isEmpty) return 0.6;

    final candidateNorm = normalize(candidate.artist);
    if (candidateNorm.isEmpty) return 0.2;

    var best = 0.0;
    for (final name in names) {
      final n = normalize(name);
      if (n.isEmpty) continue;
      if (candidateNorm == n ||
          candidateNorm.contains(n) ||
          n.contains(candidateNorm)) {
        return 1;
      }
      final score = _similarity(n, candidateNorm);
      if (score > best) best = score;
    }
    return best;
  }

  double _durationScore(int? spotifyMs, int? ytSec) {
    if (spotifyMs == null || ytSec == null || spotifyMs <= 0 || ytSec <= 0) {
      return 0.5;
    }
    final diff = ((spotifyMs / 1000.0) - ytSec).abs();
    if (diff <= 5) return 1;
    if (diff >= 30) return 0;
    return 1 - (diff - 5) / 25;
  }

  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) {
      final shorter = a.length < b.length ? a.length : b.length;
      final longer = a.length > b.length ? a.length : b.length;
      return 0.75 + 0.25 * (shorter / longer);
    }

    final wa = a.split(' ').where((w) => w.isNotEmpty).toSet();
    final wb = b.split(' ').where((w) => w.isNotEmpty).toSet();
    if (wa.isEmpty || wb.isEmpty) return 0;
    final inter = wa.intersection(wb).length;
    final union = wa.union(wb).length;
    return union == 0 ? 0 : inter / union;
  }
}
