import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';
import '../../models/library_models.dart';
import '../../models/playlist_import.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import 'ytmusic_track_matcher.dart';

/// Pulls the remote tracklist into a linked local playlist (remote wins).
class RefreshLinkedPlaylistUseCase {
  RefreshLinkedPlaylistUseCase(
    this._musicRepository,
    this._libraryRepository, {
    Future<SpotifyPlaylistSnapshot> Function(String playlistId)? fetchSpotify,
    this.searchSpacing = const Duration(milliseconds: 150),
    Future<void> Function(Duration duration)? delay,
    YtMusicTrackMatcher matcher = const YtMusicTrackMatcher(),
  }) : _fetchSpotify = fetchSpotify,
       _delay = delay ?? Future<void>.delayed,
       _matcher = matcher;

  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final Future<SpotifyPlaylistSnapshot> Function(String playlistId)?
  _fetchSpotify;
  final Duration searchSpacing;
  final Future<void> Function(Duration duration) _delay;
  final YtMusicTrackMatcher _matcher;

  Future<PlaylistSyncResult> execute(
    int localPlaylistId, {
    void Function(int current, int total)? onProgress,
  }) async {
    final playlist = await _libraryRepository.getPlaylist(localPlaylistId);
    if (playlist == null) {
      throw StateError('Playlist $localPlaylistId not found');
    }
    if (!playlist.isLinked) {
      throw StateError('Playlist is not linked to a remote source');
    }

    final sourceKind = playlist.sourceKind!;
    final remoteId = playlist.remoteId!;

    late List<PlaylistEntryModel> desired;
    var skipped = 0;
    late final String remoteName;

    if (sourceKind == 'youtube') {
      final details = await _musicRepository.getPlaylist(remoteId);
      remoteName = details.name;
      final videos = await _musicRepository.getPlaylistVideos(remoteId);
      final playable = playableVideos(videos);
      skipped = videos.length - playable.length;
      if (playable.isEmpty) {
        throw Exception('The playlist is empty or could not be retrieved');
      }
      onProgress?.call(playable.length, playable.length);
      desired =
          playable.asMap().entries.map((e) {
            final video = e.value;
            return PlaylistEntryModel(
              playlistId: localPlaylistId,
              videoId: video.videoId,
              position: e.key,
              title: video.name,
              artist: displayArtists(video.artists),
              artistsJson: encodeArtistsJson(video.artists),
              thumbnailUrl:
                  video.thumbnails.isNotEmpty
                      ? video.thumbnails.last.url
                      : null,
              duration: video.duration,
              isVideo: false,
              isExplicit: video.isExplicit,
            );
          }).toList();
    } else if (sourceKind == 'spotify') {
      final fetch = _fetchSpotify;
      if (fetch == null) {
        throw StateError('Spotify fetch is not configured');
      }

      final currentEarly = await _libraryRepository.getPlaylistEntries(
        localPlaylistId,
      );

      // Single fetch — CDN freshness is handled by the 12h Spotify sync gate.
      var snapshot = await fetch(remoteId);

      var built = await _buildFromSpotifySnapshot(
        localPlaylistId: localPlaylistId,
        snapshot: snapshot,
        current: currentEarly,
        onProgress: onProgress,
      );

      if (built.entries.isEmpty) {
        throw Exception(
          'No tracks from this Spotify playlist could be matched on YouTube Music',
        );
      }

      // Guard against a single stale short embed wiping local tracks.
      final shrinkDiff = diffPlaylistEntries(currentEarly, built.entries);
      if (shrinkDiff.removed > 0 && shrinkDiff.added == 0) {
        await _delay(const Duration(seconds: 2));
        final confirm = await fetch(remoteId);
        if (_spotifyFingerprint(confirm) != _spotifyFingerprint(snapshot)) {
          throw SpotifyEmbedUnstableException();
        }
      }

      remoteName = snapshot.name;
      desired = built.entries;
      skipped = built.skipped;
    } else {
      throw StateError('Unknown source kind: $sourceKind');
    }

    final current = await _libraryRepository.getPlaylistEntries(
      localPlaylistId,
    );

    final diff = diffPlaylistEntries(current, desired);

    await _libraryRepository.replacePlaylistEntries(localPlaylistId, desired);

    final nameUpdated =
        playlist.remoteName == null || playlist.name == playlist.remoteName;
    final newLocalName = nameUpdated ? remoteName : playlist.name;

    await _libraryRepository.updatePlaylist(
      localPlaylistId,
      name: nameUpdated ? remoteName : null,
      remoteName: remoteName,
      lastSyncedAt: DateTime.now(),
      linkStatus: PlaylistLinkStatus.linked,
    );

    final result = PlaylistSyncResult(
      localPlaylistId: localPlaylistId,
      name: newLocalName,
      added: diff.added,
      removed: diff.removed,
      reordered: diff.reordered,
      skipped: skipped,
      nameUpdated: nameUpdated && playlist.name != remoteName,
    );

    return result;
  }

  String _spotifyFingerprint(SpotifyPlaylistSnapshot snapshot) {
    return snapshot.tracks
        .map((t) => t.uri ?? '${t.title}\u0001${t.subtitle}')
        .join('\u0002');
  }

  Future<({List<PlaylistEntryModel> entries, int skipped})>
  _buildFromSpotifySnapshot({
    required int localPlaylistId,
    required SpotifyPlaylistSnapshot snapshot,
    required List<PlaylistEntryModel> current,
    void Function(int current, int total)? onProgress,
  }) async {
    final tracks = snapshot.tracks;
    if (tracks.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    onProgress?.call(0, tracks.length);
    final matched = <PlaylistEntryModel>[];
    final seenVideoIds = <String>{};
    var skipped = 0;

    for (var i = 0; i < tracks.length; i++) {
      if (i > 0 && searchSpacing > Duration.zero) {
        await _delay(searchSpacing);
      }
      final resolve = await _resolveSpotifyTrackDetailed(tracks[i]);
      final candidate = resolve.candidate;
      if (candidate == null) {
        skipped++;
      } else if (!seenVideoIds.add(candidate.videoId)) {
        skipped++;
      } else {
        matched.add(
          PlaylistEntryModel(
            playlistId: localPlaylistId,
            videoId: candidate.videoId,
            position: matched.length,
            title: candidate.title,
            artist: candidate.artist,
            artistsJson: candidate.artistsJson,
            thumbnailUrl: candidate.thumbnailUrl,
            duration: candidate.durationSec,
            isVideo: false,
            isExplicit: candidate.isExplicit,
          ),
        );
      }
      onProgress?.call(i + 1, tracks.length);
    }

    final hydrated = await _hydrateMissingThumbnails(matched, current);
    return (entries: hydrated, skipped: skipped);
  }

  Future<({ImportedTrackCandidate? candidate, bool fromCache})>
  _resolveSpotifyTrackDetailed(SpotifyPlaylistTrack track) async {
    final uri = track.uri;
    if (uri != null && uri.isNotEmpty) {
      final cached = await _libraryRepository.getCachedSpotifyMatch(uri);
      if (cached != null) {
        return (
          candidate: ImportedTrackCandidate(
            videoId: cached.videoId,
            title: cached.title ?? track.title,
            artist: track.primaryArtist,
            durationSec:
                track.durationMs != null ? track.durationMs! ~/ 1000 : null,
            isExplicit: track.isExplicit,
          ),
          fromCache: true,
        );
      }
    }

    final matched = await _matchTrack(track);
    if (matched != null && uri != null && uri.isNotEmpty) {
      await _libraryRepository.upsertSpotifyMatch(
        spotifyTrackUri: uri,
        videoId: matched.videoId,
        title: matched.title,
      );
    }
    return (candidate: matched, fromCache: false);
  }

  /// Cache hits omit YTM artwork; restore from prior entries or fetch by videoId.
  Future<List<PlaylistEntryModel>> _hydrateMissingThumbnails(
    List<PlaylistEntryModel> desired,
    List<PlaylistEntryModel> current,
  ) async {
    final currentById = {for (final e in current) e.videoId: e};
    final out = <PlaylistEntryModel>[];

    for (final e in desired) {
      if (e.thumbnailUrl?.isNotEmpty == true) {
        out.add(e);
        continue;
      }

      final prev = currentById[e.videoId];
      if (prev?.thumbnailUrl?.isNotEmpty == true) {
        out.add(
          PlaylistEntryModel(
            playlistId: e.playlistId,
            videoId: e.videoId,
            position: e.position,
            title: e.title,
            artist:
                (e.artist != null && e.artist!.isNotEmpty)
                    ? e.artist
                    : prev!.artist,
            artistsJson: e.artistsJson ?? prev!.artistsJson,
            thumbnailUrl: prev!.thumbnailUrl,
            duration: e.duration ?? prev.duration,
            isVideo: e.isVideo,
            isExplicit: e.isExplicit,
          ),
        );
        continue;
      }

      try {
        final song = await _musicRepository.getSong(e.videoId);
        final thumb =
            song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null;
        final artistName = displayArtists(song.artists);
        out.add(
          PlaylistEntryModel(
            playlistId: e.playlistId,
            videoId: e.videoId,
            position: e.position,
            title: song.name.isNotEmpty ? song.name : e.title,
            artist: artistName.isNotEmpty ? artistName : e.artist,
            artistsJson: encodeArtistsJson(song.artists) ?? e.artistsJson,
            thumbnailUrl: thumb,
            duration: song.duration,
            isVideo: e.isVideo,
            isExplicit: song.isExplicit,
          ),
        );
      } catch (_) {
        out.add(e);
      }
    }

    return out;
  }

  Future<ImportedTrackCandidate?> _matchTrack(
    SpotifyPlaylistTrack track,
  ) async {
    for (final query in _matcher.searchQueries(track)) {
      if (query.trim().isEmpty) continue;
      try {
        final results = await _musicRepository.searchSongs(query, limit: 8);
        final candidates = results
            .where((song) => song.videoId.isNotEmpty && song.isPlayable)
            .map(
              (song) => ImportedTrackCandidate(
                videoId: song.videoId,
                title: song.name,
                artist: displayArtists(song.artists),
                artistsJson: encodeArtistsJson(song.artists),
                durationSec: song.duration,
                thumbnailUrl:
                    song.thumbnails.isNotEmpty
                        ? song.thumbnails.last.url
                        : null,
                isExplicit: song.isExplicit,
              ),
            )
            .toList(growable: false);
        final match = _matcher.pickBest(track: track, candidates: candidates);
        if (match != null) return match;
      } catch (_) {
        // Try the next query.
      }
    }
    return null;
  }
}

/// Diff current vs desired ordered videoId lists.
({int added, int removed, bool reordered}) diffPlaylistEntries(
  List<PlaylistEntryModel> current,
  List<PlaylistEntryModel> desired,
) {
  final currentIds = current.map((e) => e.videoId).toList();
  final desiredIds = desired.map((e) => e.videoId).toList();
  final currentSet = currentIds.toSet();
  final desiredSet = desiredIds.toSet();

  final added = desiredSet.difference(currentSet).length;
  final removed = currentSet.difference(desiredSet).length;
  final reordered =
      added == 0 &&
      removed == 0 &&
      currentIds.length == desiredIds.length &&
      !_listEquals(currentIds, desiredIds);

  return (added: added, removed: removed, reordered: reordered);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
