import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../core/utils/artists_utils.dart';
import '../../models/playlist_import.dart';
import '../../repositories/music_repository.dart';
import '../ai/resolve_spotify_ambiguous_tracks_use_case.dart';
import '../ai/rewrite_spotify_search_query_use_case.dart';
import 'ytmusic_track_matcher.dart';

/// Shared Spotify → YTM search + classify (+ optional batch Ask resolve / rewrite).
class SpotifyYtmMatchPipeline {
  SpotifyYtmMatchPipeline(
    this._musicRepository, {
    this._matcher = const YtMusicTrackMatcher(),
    this._rewrite,
    this._resolveAmbiguous,
  });

  final MusicRepository _musicRepository;
  final YtMusicTrackMatcher _matcher;
  final RewriteSpotifySearchQueryUseCase? _rewrite;
  final ResolveSpotifyAmbiguousTracksUseCase? _resolveAmbiguous;

  bool get hasBatchResolver => _resolveAmbiguous != null;

  /// Collects candidates across [YtMusicTrackMatcher.searchQueries], classifies,
  /// and when not auto and [tryRewrite] is true (without a batch resolver),
  /// runs one single-track LLM rewrite + re-search.
  Future<SpotifyTrackMatchOutcome> matchTrack(
    SpotifyPlaylistTrack track, {
    bool tryRewrite = false,
  }) async {
    var candidates = await _searchAll(_matcher.searchQueries(track));
    var outcome = _matcher.classify(track: track, candidates: candidates);
    if (outcome.isAuto || !tryRewrite || _rewrite == null) {
      return outcome;
    }

    final rewritten = await _rewrite.execute(
      title: track.title,
      artist: track.primaryArtist,
    );
    if (rewritten == null || rewritten.trim().isEmpty) {
      return outcome;
    }

    final alreadyTried = _matcher
        .searchQueries(track)
        .map((q) => q.trim())
        .toSet();
    if (alreadyTried.contains(rewritten.trim())) {
      return outcome;
    }

    final extra = await _searchAll([rewritten.trim()]);
    if (extra.isEmpty) return outcome;

    final byId = <String, ImportedTrackCandidate>{
      for (final c in candidates) c.videoId: c,
      for (final c in extra) c.videoId: c,
    };
    return _matcher.classify(
      track: track,
      candidates: byId.values.toList(growable: false),
    );
  }

  /// Resolves unresolved (`needsReview` / `none`) slots in batches of 12 using
  /// Ask disambiguation and query rewrite. Falls back to [slots] unchanged if
  /// unconfigured or errored.
  Future<List<SpotifyImportSlot>> resolveAmbiguousSlots(
    List<SpotifyImportSlot> slots, {
    String locale = 'en',
    bool Function()? shouldAbort,
  }) async {
    final resolver = _resolveAmbiguous;
    if (resolver == null) return slots;

    final decisions = await resolver.execute(
      slots,
      locale: locale,
      shouldAbort: shouldAbort,
    );
    if (decisions.isEmpty) return slots;

    final updated = <SpotifyImportSlot>[];
    for (final slot in slots) {
      final decision = decisions[slot.index];
      if (decision == null || slot.kind == SpotifyMatchKind.auto) {
        updated.add(slot);
        continue;
      }

      if (decision.selectedVideoId != null) {
        ImportedTrackCandidate? matched;
        for (final c in slot.reviewCandidates) {
          if (c.videoId == decision.selectedVideoId) {
            matched = c;
            break;
          }
        }
        if (matched != null) {
          updated.add(slot.withCandidate(matched));
          continue;
        }
      }

      final rq = decision.rewrittenQuery?.trim();
      if (rq != null && rq.isNotEmpty) {
        final extra = await _searchAll([rq]);
        if (extra.isNotEmpty) {
          final byId = <String, ImportedTrackCandidate>{
            for (final c in slot.reviewCandidates) c.videoId: c,
            for (final c in extra) c.videoId: c,
          };
          final outcome = _matcher.classify(
            track: slot.track,
            candidates: byId.values.toList(growable: false),
          );
          updated.add(
            SpotifyImportSlot(
              index: slot.index,
              track: slot.track,
              kind: outcome.kind,
              candidate: outcome.match,
              reviewCandidates: outcome.reviewCandidates,
            ),
          );
          continue;
        }
      }

      updated.add(slot);
    }
    return updated;
  }

  Future<List<ImportedTrackCandidate>> _searchAll(List<String> queries) async {
    final byId = <String, ImportedTrackCandidate>{};
    for (final query in queries) {
      if (query.trim().isEmpty) continue;
      try {
        final results = await _musicRepository.searchSongs(query, limit: 8);
        for (final song in results) {
          if (song.videoId.isEmpty || !song.isPlayable) continue;
          byId.putIfAbsent(song.videoId, () => _toCandidate(song));
        }
      } catch (_) {
        // Try the next query; a single failed search should not abort import.
      }
    }
    return byId.values.toList(growable: false);
  }

  ImportedTrackCandidate _toCandidate(SongDetailed song) {
    return ImportedTrackCandidate(
      videoId: song.videoId,
      title: song.name,
      artist: displayArtists(song.artists),
      artistsJson: encodeArtistsJson(song.artists),
      durationSec: song.duration,
      thumbnailUrl: song.thumbnails.isNotEmpty
          ? song.thumbnails.last.url
          : null,
      isExplicit: song.isExplicit,
    );
  }
}
