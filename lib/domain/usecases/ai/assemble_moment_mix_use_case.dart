import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';
import '../../models/library_models.dart';
import '../../models/music_search_intent.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import 'moment_mix_assembler.dart';

/// Drop YTM search hits longer than this (compilations / "mix" streams).
const kMomentMixMaxTrackDurationSec = 20 * 60;

/// Result of assembling a moment mix from [MusicSearchIntent].
class MomentMixQueue {
  const MomentMixQueue({required this.tracks, required this.intent});

  /// History / liked / mapped YTM rows suitable for [PlaySmartMixUseCase].
  final List<dynamic> tracks;
  final MusicSearchIntent intent;

  bool get isEmpty => tracks.isEmpty;
}

/// Intent → capped playable queue. Never invents video IDs.
class AssembleMomentMixUseCase {
  AssembleMomentMixUseCase(
    this._library,
    this._music, {
    MomentMixAssembler assembler = const MomentMixAssembler(),
  }) : _assembler = assembler;

  final LibraryRepository _library;
  final MusicRepository _music;
  final MomentMixAssembler _assembler;

  /// Builds a mix queue.
  ///
  /// When [allowYtm] is false (offline), YTM search is skipped and
  /// `source: ytm` yields an empty list.
  Future<MomentMixQueue> execute({
    required MusicSearchIntent intent,
    required bool allowYtm,
  }) async {
    final wantHistory =
        intent.source == MixSource.history || intent.source == MixSource.both;
    final wantYtm =
        intent.source == MixSource.ytm || intent.source == MixSource.both;

    List<dynamic> local = const [];
    if (wantHistory) {
      final history = await _library.getMostPlayedSongs(limit: 200);
      final recent = await _library.getRecentHistory(limit: 100);
      final liked = await _library.getAllLikedSongs();
      final forgotten = await _library.getForgottenFavorites();

      final historyPool = _dedupeHistory([...history, ...recent]);
      final likedPool = _dedupeLiked([...liked, ...forgotten]);

      local = _assembler.selectLocalTracks(
        intent: intent,
        history: historyPool,
        liked: likedPool,
      );
    }

    List<LikedSongModel> ytmMapped = const [];
    if (wantYtm && allowYtm) {
      try {
        final songs = await _music.searchSongs(
          intent.searchQuery,
          limit: kMomentMixTrackCap,
        );
        ytmMapped = [
          for (final s in playableSongs(songs))
            if (_isSongLengthOk(s.duration)) _mapSongDetailed(s),
        ];
      } catch (_) {
        ytmMapped = const [];
      }
    }

    final List<dynamic> tracks;
    if (wantHistory && wantYtm) {
      tracks = _assembler.mergeDedupe(historyFirst: local, ytm: ytmMapped);
    } else if (wantHistory) {
      tracks = local.take(kMomentMixTrackCap).toList(growable: false);
    } else {
      tracks = ytmMapped.take(kMomentMixTrackCap).toList(growable: false);
    }

    return MomentMixQueue(tracks: tracks, intent: intent);
  }

  List<HistoryModel> _dedupeHistory(List<HistoryModel> rows) {
    final seen = <String>{};
    final out = <HistoryModel>[];
    for (final h in rows) {
      if (h.videoId.isEmpty || seen.contains(h.videoId)) continue;
      seen.add(h.videoId);
      out.add(h);
    }
    return out;
  }

  List<LikedSongModel> _dedupeLiked(List<LikedSongModel> rows) {
    final seen = <String>{};
    final out = <LikedSongModel>[];
    for (final s in rows) {
      if (s.videoId.isEmpty || seen.contains(s.videoId)) continue;
      seen.add(s.videoId);
      out.add(s);
    }
    return out;
  }

  LikedSongModel _mapSongDetailed(SongDetailed s) {
    return LikedSongModel(
      videoId: s.videoId,
      title: s.name,
      artist: displayArtists(s.artists),
      thumbnailUrl: s.thumbnails.isNotEmpty ? s.thumbnails.last.url : null,
      artistId: primaryArtistId(s.artists),
      albumId: s.albumId ?? s.album?.albumId,
      artistsJson: encodeArtistsJson(s.artists),
      addedAt: DateTime.fromMillisecondsSinceEpoch(0),
      isVideo: false,
      duration: s.duration,
      isExplicit: s.isExplicit,
    );
  }

  /// Keep unknown duration; drop known mega-mix / compilation hits.
  bool _isSongLengthOk(int? durationSec) {
    if (durationSec == null || durationSec <= 0) return true;
    return durationSec <= kMomentMixMaxTrackDurationSec;
  }
}
