import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';
import '../../models/library_models.dart';
import '../../models/playlist_import.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import '../ai/rewrite_spotify_search_query_use_case.dart';
import 'import_spotify_playlist_use_case.dart';
import 'spotify_ytm_match_pipeline.dart';
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
    RewriteSpotifySearchQueryUseCase? rewriteSearchQuery,
  }) : _fetchSpotify = fetchSpotify,
       _delay = delay ?? Future<void>.delayed,
       _pipeline = SpotifyYtmMatchPipeline(
         _musicRepository,
         matcher: matcher,
         rewrite: rewriteSearchQuery,
       );

  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final Future<SpotifyPlaylistSnapshot> Function(String playlistId)?
  _fetchSpotify;
  final Duration searchSpacing;
  final Future<void> Function(Duration duration) _delay;
  final SpotifyYtmMatchPipeline _pipeline;

  /// Full sync. Spotify ambiguous tracks are skipped (legacy). Prefer
  /// [prepareSpotify] + review + [commitSpotify] from the UI.
  Future<PlaylistSyncResult> execute(
    int localPlaylistId, {
    void Function(int current, int total)? onProgress,
    bool tryRewrite = false,
  }) async {
    final playlist = await _requireLinkedPlaylist(localPlaylistId);
    final sourceKind = playlist.sourceKind!;

    if (sourceKind == 'youtube') {
      return _executeYoutube(playlist, onProgress: onProgress);
    }
    if (sourceKind == 'spotify') {
      final plan = await prepareSpotify(
        localPlaylistId,
        onProgress: onProgress,
        tryRewrite: tryRewrite,
      );
      final resolved = applySpotifyReviewChoices(plan, const {});
      return commitSpotify(resolved);
    }
    throw StateError('Unknown source kind: $sourceKind');
  }

  Future<SpotifyRefreshPlan> prepareSpotify(
    int localPlaylistId, {
    void Function(int current, int total)? onProgress,
    bool tryRewrite = false,
  }) async {
    final playlist = await _requireLinkedPlaylist(localPlaylistId);
    if (playlist.sourceKind != 'spotify') {
      throw StateError('Playlist is not linked to Spotify');
    }
    final fetch = _fetchSpotify;
    if (fetch == null) {
      throw StateError('Spotify fetch is not configured');
    }

    final remoteId = playlist.remoteId!;
    final current = await _libraryRepository.getPlaylistEntries(
      localPlaylistId,
    );
    final snapshot = await fetch(remoteId);
    final tracks = snapshot.tracks;
    if (tracks.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    onProgress?.call(0, tracks.length);
    final slots = <SpotifyImportSlot>[];

    for (var i = 0; i < tracks.length; i++) {
      if (i > 0 && searchSpacing > Duration.zero) {
        await _delay(searchSpacing);
      }

      final cached = await _cachedCandidate(tracks[i]);
      if (cached != null) {
        slots.add(
          SpotifyImportSlot(
            index: i,
            track: tracks[i],
            kind: SpotifyMatchKind.auto,
            candidate: cached,
          ),
        );
      } else {
        final outcome = await _pipeline.matchTrack(
          tracks[i],
          tryRewrite: tryRewrite,
        );
        slots.add(
          SpotifyImportSlot(
            index: i,
            track: tracks[i],
            kind: outcome.kind,
            candidate: outcome.match,
            reviewCandidates: outcome.reviewCandidates,
          ),
        );
      }
      onProgress?.call(i + 1, tracks.length);
    }

    return SpotifyRefreshPlan(
      playlist: playlist,
      snapshot: snapshot,
      currentEntries: current,
      slots: slots,
    );
  }

  static SpotifyRefreshPlan applySpotifyReviewChoices(
    SpotifyRefreshPlan plan,
    Map<int, ImportedTrackCandidate?> choices,
  ) {
    final importPlan = ImportSpotifyPlaylistUseCase.applyReviewChoices(
      SpotifyImportPlan(snapshot: plan.snapshot, slots: plan.slots),
      choices,
    );
    return SpotifyRefreshPlan(
      playlist: plan.playlist,
      snapshot: plan.snapshot,
      currentEntries: plan.currentEntries,
      slots: importPlan.slots,
    );
  }

  Future<PlaylistSyncResult> commitSpotify(SpotifyRefreshPlan plan) async {
    final fetch = _fetchSpotify;
    if (fetch == null) {
      throw StateError('Spotify fetch is not configured');
    }

    final localPlaylistId = plan.localPlaylistId;
    final built = _entriesFromSlots(
      localPlaylistId: localPlaylistId,
      slots: plan.slots,
    );

    if (built.entries.isEmpty) {
      throw Exception(
        'No tracks from this Spotify playlist could be matched on YouTube Music',
      );
    }

    // Guard against a single stale short embed wiping local tracks.
    final shrinkDiff = diffPlaylistEntries(plan.currentEntries, built.entries);
    if (shrinkDiff.removed > 0 && shrinkDiff.added == 0) {
      await _delay(const Duration(seconds: 2));
      final confirm = await fetch(plan.playlist.remoteId!);
      if (_spotifyFingerprint(confirm) != _spotifyFingerprint(plan.snapshot)) {
        throw SpotifyEmbedUnstableException();
      }
    }

    // Persist newly chosen matches (not already cached).
    for (final slot in plan.slots) {
      final candidate = slot.candidate;
      final uri = slot.track.uri;
      if (candidate == null || uri == null || uri.isEmpty) continue;
      final existing = await _libraryRepository.getCachedSpotifyMatch(uri);
      if (existing != null) continue;
      await _libraryRepository.upsertSpotifyMatch(
        spotifyTrackUri: uri,
        videoId: candidate.videoId,
        title: candidate.title,
      );
    }

    final hydrated = await _hydrateMissingThumbnails(
      built.entries,
      plan.currentEntries,
    );

    return _finalizeReplace(
      playlist: plan.playlist,
      remoteName: plan.snapshot.name,
      desired: hydrated,
      skipped: built.skipped,
    );
  }

  Future<PlaylistSyncResult> _executeYoutube(
    LocalPlaylistModel playlist, {
    void Function(int current, int total)? onProgress,
  }) async {
    final localPlaylistId = playlist.id;
    final remoteId = playlist.remoteId!;
    final details = await _musicRepository.getPlaylist(remoteId);
    final videos = await _musicRepository.getPlaylistVideos(remoteId);
    final playable = playableVideos(videos);
    final skipped = videos.length - playable.length;
    if (playable.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }
    onProgress?.call(playable.length, playable.length);
    final desired =
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
                video.thumbnails.isNotEmpty ? video.thumbnails.last.url : null,
            duration: video.duration,
            isVideo: false,
            isExplicit: video.isExplicit,
          );
        }).toList();

    return _finalizeReplace(
      playlist: playlist,
      remoteName: details.name,
      desired: desired,
      skipped: skipped,
    );
  }

  Future<PlaylistSyncResult> _finalizeReplace({
    required LocalPlaylistModel playlist,
    required String remoteName,
    required List<PlaylistEntryModel> desired,
    required int skipped,
  }) async {
    final localPlaylistId = playlist.id;
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

    return PlaylistSyncResult(
      localPlaylistId: localPlaylistId,
      name: newLocalName,
      added: diff.added,
      removed: diff.removed,
      reordered: diff.reordered,
      skipped: skipped,
      nameUpdated: nameUpdated && playlist.name != remoteName,
    );
  }

  Future<LocalPlaylistModel> _requireLinkedPlaylist(int localPlaylistId) async {
    final playlist = await _libraryRepository.getPlaylist(localPlaylistId);
    if (playlist == null) {
      throw StateError('Playlist $localPlaylistId not found');
    }
    if (!playlist.isLinked) {
      throw StateError('Playlist is not linked to a remote source');
    }
    return playlist;
  }

  Future<ImportedTrackCandidate?> _cachedCandidate(
    SpotifyPlaylistTrack track,
  ) async {
    final uri = track.uri;
    if (uri == null || uri.isEmpty) return null;
    final cached = await _libraryRepository.getCachedSpotifyMatch(uri);
    if (cached == null) return null;
    return ImportedTrackCandidate(
      videoId: cached.videoId,
      title: cached.title ?? track.title,
      artist: track.primaryArtist,
      durationSec: track.durationMs != null ? track.durationMs! ~/ 1000 : null,
      isExplicit: track.isExplicit,
    );
  }

  ({List<PlaylistEntryModel> entries, int skipped}) _entriesFromSlots({
    required int localPlaylistId,
    required List<SpotifyImportSlot> slots,
  }) {
    final matched = <PlaylistEntryModel>[];
    final seenVideoIds = <String>{};
    var skipped = 0;

    for (final slot in slots) {
      final candidate = slot.candidate;
      if (candidate == null) {
        skipped++;
        continue;
      }
      if (!seenVideoIds.add(candidate.videoId)) {
        skipped++;
        continue;
      }
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
    return (entries: matched, skipped: skipped);
  }

  String _spotifyFingerprint(SpotifyPlaylistSnapshot snapshot) {
    return snapshot.tracks
        .map((t) => t.uri ?? '${t.title}\u0001${t.subtitle}')
        .join('\u0002');
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
