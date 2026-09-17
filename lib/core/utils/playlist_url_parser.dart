import '../../domain/models/playlist_import.dart';

/// Detects YouTube Music / YouTube and Spotify playlist URLs or ids.
class PlaylistUrlParser {
  PlaylistUrlParser._();

  static final _spotifyOpen = RegExp(
    r'(?:open|play)\.spotify\.com/(?:embed/)?(?:intl-[a-z]{2}/)?playlist/([A-Za-z0-9]+)',
    caseSensitive: false,
  );
  static final _spotifyUri = RegExp(
    r'spotify:playlist:([A-Za-z0-9]+)',
    caseSensitive: false,
  );
  static final _youtubeListParam = RegExp(r'[?&]list=([^#&?]+)');
  static final _youtubeId = RegExp(r'^[a-zA-Z0-9_-]{12,}$');

  static RemotePlaylistRef? parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final spotifyId = _spotifyId(trimmed);
    if (spotifyId != null) {
      return RemotePlaylistRef(kind: PlaylistImportKind.spotify, id: spotifyId);
    }

    final youtubeId = _youtubeIdFrom(trimmed);
    if (youtubeId != null) {
      return RemotePlaylistRef(kind: PlaylistImportKind.youtube, id: youtubeId);
    }

    return null;
  }

  static String? _spotifyId(String input) {
    final open = _spotifyOpen.firstMatch(input);
    if (open != null) return open.group(1);

    final uri = _spotifyUri.firstMatch(input);
    if (uri != null) return uri.group(1);

    return null;
  }

  static String? _youtubeIdFrom(String input) {
    final isUrl =
        input.startsWith('http://') ||
        input.startsWith('https://') ||
        input.contains('youtube.com') ||
        input.contains('youtu.be') ||
        input.contains('music.youtube.com');

    if (isUrl) {
      final isYoutubeDomain =
          input.contains('youtube.com') || input.contains('youtu.be');
      if (!isYoutubeDomain) return null;

      final match = _youtubeListParam.firstMatch(input);
      return match?.group(1);
    }

    if (_youtubeId.hasMatch(input)) return input;
    return null;
  }
}
