import '../../../core/utils/playlist_url_parser.dart';
import '../../models/playlist_import.dart';
import 'import_spotify_playlist_use_case.dart';
import 'sync_youtube_playlist_use_case.dart';

/// Routes a pasted URL to the YouTube or Spotify import path.
class ImportRemotePlaylistUseCase {
  ImportRemotePlaylistUseCase(this._youtube, this._spotify);

  final SyncYoutubePlaylistUseCase _youtube;
  final ImportSpotifyPlaylistUseCase _spotify;

  Future<PlaylistImportResult> execute(
    String playlistUrlOrId, {
    void Function(int current, int total)? onProgress,
  }) async {
    final ref = PlaylistUrlParser.parse(playlistUrlOrId);
    if (ref == null) {
      throw ArgumentError('Invalid playlist URL or ID');
    }
    switch (ref.kind) {
      case PlaylistImportKind.youtube:
        return _youtube.execute(playlistUrlOrId);
      case PlaylistImportKind.spotify:
        return _spotify.execute(ref.id, onProgress: onProgress);
    }
  }
}
