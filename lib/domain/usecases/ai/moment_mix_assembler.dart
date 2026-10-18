import '../../models/library_models.dart';
import '../../models/music_search_intent.dart';

/// Default cap for a moment-mix queue (history and/or YTM).
const kMomentMixTrackCap = 40;

/// Pure ranking / filtering of local history + liked for a mix intent.
///
/// Unit-testable: no I/O. Never invents video IDs — only ranks rows already
/// present in [history] / [liked].
class MomentMixAssembler {
  const MomentMixAssembler({this.cap = kMomentMixTrackCap});

  final int cap;

  /// Scores and selects local tracks matching [intent].
  ///
  /// History rows win over liked when the same [videoId] appears in both.
  List<dynamic> selectLocalTracks({
    required MusicSearchIntent intent,
    required List<HistoryModel> history,
    required List<LikedSongModel> liked,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final tokens = _tokensFor(intent);
    final byId = <String, _ScoredTrack>{};

    for (final h in history) {
      if (h.videoId.isEmpty) continue;
      if (h.contentType == 'episode') continue;
      final score = _scoreHistory(
        h,
        intent: intent,
        tokens: tokens,
        now: clock,
      );
      final existing = byId[h.videoId];
      if (existing == null || score > existing.score) {
        byId[h.videoId] = _ScoredTrack(track: h, score: score);
      }
    }

    for (final song in liked) {
      if (song.videoId.isEmpty) continue;
      if (byId.containsKey(song.videoId)) continue;
      final score = _scoreLiked(
        song,
        intent: intent,
        tokens: tokens,
        now: clock,
      );
      byId[song.videoId] = _ScoredTrack(track: song, score: score);
    }

    final ranked =
        byId.values.toList()..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
          return _tieBreak(a.track, b.track);
        });

    // Prefer tracks that matched something; if nothing scored above baseline,
    // still return a fallback ordered by energy heuristic.
    final matched = ranked.where((s) => s.score > 0).toList();
    final pool = matched.isNotEmpty ? matched : ranked;
    return [for (final s in pool.take(cap)) s.track];
  }

  /// Merges [historyFirst] then [ytm], deduped by videoId, capped.
  List<dynamic> mergeDedupe({
    required List<dynamic> historyFirst,
    required List<dynamic> ytm,
  }) {
    final seen = <String>{};
    final out = <dynamic>[];
    for (final track in [...historyFirst, ...ytm]) {
      final id = _videoIdOf(track);
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      out.add(track);
      if (out.length >= cap) break;
    }
    return out;
  }

  Set<String> _tokensFor(MusicSearchIntent intent) {
    final raw = <String>[
      intent.searchQuery,
      ...intent.genres,
      ...intent.seedArtists,
      if (intent.mood != null) intent.mood!,
      if (intent.era != null) intent.era!,
    ];
    final tokens = <String>{};
    for (final part in raw) {
      for (final t in part.toLowerCase().split(
        RegExp(r'[^a-z0-9àèéìòùäöüß]+'),
      )) {
        if (t.length >= 2) tokens.add(t);
      }
    }
    // Drop ultra-generic tokens that match everything.
    tokens.removeAll(const {
      'the',
      'and',
      'for',
      'music',
      'song',
      'songs',
      'mix',
      'play',
    });
    return tokens;
  }

  double _scoreHistory(
    HistoryModel h, {
    required MusicSearchIntent intent,
    required Set<String> tokens,
    required DateTime now,
  }) {
    var score = _textScore(
      title: h.title,
      artist: h.artist,
      intent: intent,
      tokens: tokens,
    );

    switch (intent.energy) {
      case MixEnergy.high:
        score += (h.playCount.clamp(0, 50)) * 0.4;
        break;
      case MixEnergy.low:
        final days = now.difference(h.playedAt).inDays;
        if (days >= 14) score += 8;
        if (days >= 30) score += 6;
        break;
      case MixEnergy.medium:
        score += (h.playCount.clamp(0, 20)) * 0.15;
        final days = now.difference(h.playedAt).inDays;
        if (days <= 14) score += 4;
        break;
      case MixEnergy.unknown:
        score += (h.playCount.clamp(0, 30)) * 0.2;
        break;
    }

    // Mild recency bump so empty-token fallbacks still feel current.
    final hours = now.difference(h.playedAt).inHours;
    if (hours <= 72) score += 2;

    return score;
  }

  double _scoreLiked(
    LikedSongModel song, {
    required MusicSearchIntent intent,
    required Set<String> tokens,
    required DateTime now,
  }) {
    var score = _textScore(
      title: song.title,
      artist: song.artist,
      intent: intent,
      tokens: tokens,
    );

    // Forgotten-leaning for low energy; newer likes for high.
    final days = now.difference(song.addedAt).inDays;
    switch (intent.energy) {
      case MixEnergy.low:
        if (days >= 30) score += 10;
        break;
      case MixEnergy.high:
        if (days <= 60) score += 4;
        break;
      case MixEnergy.medium:
      case MixEnergy.unknown:
        score += 1;
        break;
    }
    return score;
  }

  double _textScore({
    required String title,
    required String artist,
    required MusicSearchIntent intent,
    required Set<String> tokens,
  }) {
    final hay = '${title.toLowerCase()} ${artist.toLowerCase()}';
    var score = 0.0;

    for (final seed in intent.seedArtists) {
      final s = seed.trim().toLowerCase();
      if (s.isEmpty) continue;
      if (artist.toLowerCase().contains(s) || hay.contains(s)) {
        score += 25;
      }
    }

    for (final genre in intent.genres) {
      final g = genre.trim().toLowerCase();
      if (g.length >= 3 && hay.contains(g)) score += 12;
    }

    if (intent.era != null) {
      final era = intent.era!.trim().toLowerCase();
      if (era.isNotEmpty && hay.contains(era)) score += 8;
    }

    for (final t in tokens) {
      if (hay.contains(t)) score += 4;
    }

    return score;
  }

  int _tieBreak(dynamic a, dynamic b) {
    final aPlay = a is HistoryModel ? a.playCount : 0;
    final bPlay = b is HistoryModel ? b.playCount : 0;
    final byPlay = bPlay.compareTo(aPlay);
    if (byPlay != 0) return byPlay;
    final aTitle =
        a is HistoryModel
            ? a.title
            : a is LikedSongModel
            ? a.title
            : '';
    final bTitle =
        b is HistoryModel
            ? b.title
            : b is LikedSongModel
            ? b.title
            : '';
    return aTitle.compareTo(bTitle);
  }

  String? _videoIdOf(dynamic track) {
    if (track is HistoryModel) return track.videoId;
    if (track is LikedSongModel) return track.videoId;
    try {
      return track.videoId as String?;
    } catch (_) {
      return null;
    }
  }
}

class _ScoredTrack {
  const _ScoredTrack({required this.track, required this.score});
  final dynamic track;
  final double score;
}
