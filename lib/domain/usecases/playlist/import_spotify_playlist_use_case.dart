import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../models/playlist_import.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import 'ytmusic_track_matcher.dart';

class ImportSpotifyPlaylistUseCase {
  ImportSpotifyPlaylistUseCase(
    this._fetchPlaylist,
    this._musicRepository,
    this._libraryRepository, {
    this.searchSpacing = const Duration(milliseconds: 150),
    Future<void> Function(Duration duration)? delay,
    YtMusicTrackMatcher matcher = const YtMusicTrackMatcher(),
  }) : _delay = delay ?? Future<void>.delayed,
       _matcher = matcher;

  final Future<SpotifyPlaylistSnapshot> Function(String playlistId)
  _fetchPlaylist;
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final Duration searchSpacing;
  final Future<void> Function(Duration duration) _delay;
  final YtMusicTrackMatcher _matcher;

  Future<PlaylistImportResult> execute(
    String playlistId, {
    void Function(int current, int total)? onProgress,
  }) async {
    final snapshot = await _fetchPlaylist(playlistId);
    final tracks = snapshot.tracks;
    if (tracks.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    onProgress?.call(0, tracks.length);

    final matched = <ImportedTrackCandidate>[];
    final seenVideoIds = <String>{};
    var skipped = 0;

    for (var i = 0; i < tracks.length; i++) {
      if (i > 0 && searchSpacing > Duration.zero) {
        await _delay(searchSpacing);
      }

      final candidate = await _matchTrack(tracks[i]);
      if (candidate == null || !seenVideoIds.add(candidate.videoId)) {
        skipped++;
      } else {
        matched.add(candidate);
      }
      onProgress?.call(i + 1, tracks.length);
    }

    if (matched.isEmpty) {
      throw Exception(
        'No tracks from this Spotify playlist could be matched on YouTube Music',
      );
    }

    final truncatedNote =
        snapshot.truncated
            ? ' — first ${tracks.length} tracks from the public embed'
            : '';
    final localPlaylistId = await _libraryRepository.createPlaylist(
      snapshot.name,
      description: 'Imported from Spotify (ID: ${snapshot.id})$truncatedNote',
    );

    for (var i = 0; i < matched.length; i++) {
      final song = matched[i];
      await _libraryRepository.addEntry(
        localPlaylistId,
        song.videoId,
        i,
        title: song.title,
        artist: song.artist,
        thumbnailUrl: song.thumbnailUrl,
        duration: song.durationSec,
        isVideo: false,
        isExplicit: song.isExplicit,
      );
    }

    return PlaylistImportResult(
      localPlaylistId: localPlaylistId,
      name: snapshot.name,
      source: PlaylistImportKind.spotify,
      importedCount: matched.length,
      skippedCount: skipped,
    );
  }

  Future<ImportedTrackCandidate?> _matchTrack(
    SpotifyPlaylistTrack track,
  ) async {
    for (final query in _matcher.searchQueries(track)) {
      if (query.trim().isEmpty) continue;
      try {
        final results = await _musicRepository.searchSongs(query, limit: 8);
        final candidates = results
            .where((song) => song.videoId.isNotEmpty)
            .map(_toCandidate)
            .toList(growable: false);
        final match = _matcher.pickBest(track: track, candidates: candidates);
        if (match != null) return match;
      } catch (_) {
        // Try the next query; a single failed search should not abort import.
      }
    }
    return null;
  }

  ImportedTrackCandidate _toCandidate(SongDetailed song) {
    return ImportedTrackCandidate(
      videoId: song.videoId,
      title: song.name,
      artist: song.artist.name,
      durationSec: song.duration,
      thumbnailUrl:
          song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
      isExplicit: song.isExplicit,
    );
  }
}
