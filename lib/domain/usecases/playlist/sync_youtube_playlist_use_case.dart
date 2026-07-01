import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';

class SyncYoutubePlaylistUseCase {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;

  SyncYoutubePlaylistUseCase(this._musicRepository, this._libraryRepository);

  Future<int> execute(String playlistUrlOrId) async {
    final playlistId = _parsePlaylistId(playlistUrlOrId);
    if (playlistId == null || playlistId.isEmpty) {
      throw ArgumentError('Invalid playlist URL or ID');
    }

    // 1. Fetch playlist metadata
    final playlistDetails = await _musicRepository.getPlaylist(playlistId);
    final playlistName = playlistDetails.name;

    // 2. Fetch playlist videos
    final videos = await _musicRepository.getPlaylistVideos(playlistId);
    if (videos.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    // 3. Create local playlist
    final localPlaylistId = await _libraryRepository.createPlaylist(
      playlistName,
      description: 'Synced from YouTube (ID: $playlistId)',
    );

    // 4. Add each video as an entry in the playlist
    for (var i = 0; i < videos.length; i++) {
      final video = videos[i];
      final artistName = video.artist.name;
      final thumbUrl =
          video.thumbnails.isNotEmpty ? video.thumbnails.last.url : null;

      await _libraryRepository.addEntry(
        localPlaylistId,
        video.videoId,
        i, // position
        title: video.name,
        artist: artistName,
        thumbnailUrl: thumbUrl,
        isVideo: false,
        isExplicit: video.isExplicit,
      );
    }

    return localPlaylistId;
  }

  String? _parsePlaylistId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final isUrl =
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be');

    if (isUrl) {
      // Validate that the URL belongs to a YouTube or YouTube Music domain
      final isYoutubeDomain =
          trimmed.contains('youtube.com') || trimmed.contains('youtu.be');
      if (!isYoutubeDomain) return null;

      // Extract the 'list' query parameter
      final regExp = RegExp(r'[?&]list=([^#\&\?]+)');
      final match = regExp.firstMatch(trimmed);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
      return null;
    }

    // Direct ID fallback (e.g. PL..., must be alphanumeric with underscores/hyphens and at least 12 chars)
    final isValidId = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed);
    if (isValidId && trimmed.length >= 12) {
      return trimmed;
    }

    return null;
  }
}
