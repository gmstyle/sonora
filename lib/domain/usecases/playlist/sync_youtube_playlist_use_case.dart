import '../../../core/utils/playlist_url_parser.dart';
import '../../../core/utils/playable_tracks.dart';
import '../../models/library_models.dart';
import '../../models/playlist_import.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import '../../../core/utils/artists_utils.dart';

class SyncYoutubePlaylistUseCase {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;

  SyncYoutubePlaylistUseCase(this._musicRepository, this._libraryRepository);

  Future<PlaylistImportResult> execute(String playlistUrlOrId) async {
    final ref = PlaylistUrlParser.parse(playlistUrlOrId);
    if (ref == null || ref.kind != PlaylistImportKind.youtube) {
      throw ArgumentError('Invalid playlist URL or ID');
    }
    final playlistId = ref.id;

    final existing = await _libraryRepository.findLinkedPlaylist(
      'youtube',
      playlistId,
    );
    if (existing != null) {
      throw PlaylistAlreadyLinkedException(
        localPlaylistId: existing.id,
        name: existing.name,
        source: PlaylistImportKind.youtube,
        remoteId: playlistId,
      );
    }

    // 1. Fetch playlist metadata
    final playlistDetails = await _musicRepository.getPlaylist(playlistId);
    final playlistName = playlistDetails.name;

    // 2. Fetch playlist videos (drop greyed-out / unplayable rows)
    final videos = await _musicRepository.getPlaylistVideos(playlistId);
    final playable = playableVideos(videos);
    final skippedUnplayable = videos.length - playable.length;
    if (playable.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    // 3. Create local linked playlist
    final now = DateTime.now();
    final localPlaylistId = await _libraryRepository.createPlaylist(
      playlistName,
      description: 'Synced from YouTube (ID: $playlistId)',
      sourceKind: 'youtube',
      remoteId: playlistId,
      remoteName: playlistName,
      linkStatus: PlaylistLinkStatus.linked,
      lastSyncedAt: now,
    );

    // 4. Add each playable video as an entry in the playlist
    for (var i = 0; i < playable.length; i++) {
      final video = playable[i];
      final artistName = displayArtists(video.artists);
      final thumbUrl =
          video.thumbnails.isNotEmpty ? video.thumbnails.last.url : null;

      await _libraryRepository.addEntry(
        localPlaylistId,
        video.videoId,
        i, // position
        title: video.name,
        artist: artistName,
        artistsJson: encodeArtistsJson(video.artists),
        thumbnailUrl: thumbUrl,
        duration: video.duration,
        isVideo: false,
        isExplicit: video.isExplicit,
      );
    }

    return PlaylistImportResult(
      localPlaylistId: localPlaylistId,
      name: playlistName,
      source: PlaylistImportKind.youtube,
      importedCount: playable.length,
      skippedCount: skippedUnplayable,
    );
  }
}
