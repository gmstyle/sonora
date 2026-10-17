import '../../models/library_models.dart';
import '../../models/playlist_import.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import '../ai/rewrite_spotify_search_query_use_case.dart';
import 'spotify_ytm_match_pipeline.dart';
import 'ytmusic_track_matcher.dart';

class ImportSpotifyPlaylistUseCase {
  ImportSpotifyPlaylistUseCase(
    this._fetchPlaylist,
    MusicRepository musicRepository,
    this._libraryRepository, {
    this.searchSpacing = const Duration(milliseconds: 150),
    Future<void> Function(Duration duration)? delay,
    YtMusicTrackMatcher matcher = const YtMusicTrackMatcher(),
    RewriteSpotifySearchQueryUseCase? rewriteSearchQuery,
  }) : _delay = delay ?? Future<void>.delayed,
       _pipeline = SpotifyYtmMatchPipeline(
         musicRepository,
         matcher: matcher,
         rewrite: rewriteSearchQuery,
       );

  final Future<SpotifyPlaylistSnapshot> Function(String playlistId)
  _fetchPlaylist;
  final LibraryRepository _libraryRepository;
  final Duration searchSpacing;
  final Future<void> Function(Duration duration) _delay;
  final SpotifyYtmMatchPipeline _pipeline;

  /// Legacy one-shot: prepare, skip all ambiguous tracks, commit.
  Future<PlaylistImportResult> execute(
    String playlistId, {
    void Function(int current, int total)? onProgress,
    bool tryRewrite = false,
  }) async {
    final plan = await prepare(
      playlistId,
      onProgress: onProgress,
      tryRewrite: tryRewrite,
    );
    final resolved = applyReviewChoices(plan, const {});
    return commit(resolved);
  }

  /// Match all tracks. Ambiguous slots need UI review before [commit].
  Future<SpotifyImportPlan> prepare(
    String playlistId, {
    void Function(int current, int total)? onProgress,
    bool tryRewrite = false,
  }) async {
    final existing = await _libraryRepository.findLinkedPlaylist(
      'spotify',
      playlistId,
    );
    if (existing != null) {
      throw PlaylistAlreadyLinkedException(
        localPlaylistId: existing.id,
        name: existing.name,
        source: PlaylistImportKind.spotify,
        remoteId: playlistId,
      );
    }

    final snapshot = await _fetchPlaylist(playlistId);
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
      onProgress?.call(i + 1, tracks.length);
    }

    return SpotifyImportPlan(snapshot: snapshot, slots: slots);
  }

  /// Applies user choices for ambiguous [slot.index] → candidate (null = skip).
  /// Non-review slots are left as prepared. Duplicate videoIds after resolve
  /// are dropped as skips.
  static SpotifyImportPlan applyReviewChoices(
    SpotifyImportPlan plan,
    Map<int, ImportedTrackCandidate?> choices,
  ) {
    final slots = <SpotifyImportSlot>[];
    for (final slot in plan.slots) {
      if (!slot.needsReview) {
        slots.add(slot);
        continue;
      }
      if (choices.containsKey(slot.index)) {
        slots.add(slot.withCandidate(choices[slot.index]));
      } else {
        // Unresolved ambiguous → skip (same as legacy silent drop).
        slots.add(slot.withCandidate(null));
      }
    }
    return SpotifyImportPlan(snapshot: plan.snapshot, slots: slots);
  }

  Future<PlaylistImportResult> commit(SpotifyImportPlan plan) async {
    final matched = <ImportedTrackCandidate>[];
    final seenVideoIds = <String>{};
    var skipped = 0;

    for (final slot in plan.slots) {
      final candidate = slot.candidate;
      if (candidate == null || !seenVideoIds.add(candidate.videoId)) {
        skipped++;
        continue;
      }
      matched.add(candidate);
      final uri = slot.track.uri;
      if (uri != null && uri.isNotEmpty) {
        await _libraryRepository.upsertSpotifyMatch(
          spotifyTrackUri: uri,
          videoId: candidate.videoId,
          title: candidate.title,
        );
      }
    }

    if (matched.isEmpty) {
      throw Exception(
        'No tracks from this Spotify playlist could be matched on YouTube Music',
      );
    }

    final snapshot = plan.snapshot;
    final truncatedNote =
        snapshot.truncated
            ? ' — first ${snapshot.tracks.length} tracks from the public embed'
            : '';
    final now = DateTime.now();
    final localPlaylistId = await _libraryRepository.createPlaylist(
      snapshot.name,
      description: 'Imported from Spotify (ID: ${snapshot.id})$truncatedNote',
      sourceKind: 'spotify',
      remoteId: snapshot.id,
      remoteName: snapshot.name,
      linkStatus: PlaylistLinkStatus.linked,
      lastSyncedAt: now,
    );

    for (var i = 0; i < matched.length; i++) {
      final song = matched[i];
      await _libraryRepository.addEntry(
        localPlaylistId,
        song.videoId,
        i,
        title: song.title,
        artist: song.artist,
        artistsJson: song.artistsJson,
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
}
