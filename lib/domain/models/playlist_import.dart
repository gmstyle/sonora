/// Source of a remote playlist pasted into the import dialog.
enum PlaylistImportKind { youtube, spotify }

/// Parsed playlist identity (YouTube list id or Spotify playlist id).
class RemotePlaylistRef {
  final PlaylistImportKind kind;
  final String id;

  const RemotePlaylistRef({required this.kind, required this.id});

  @override
  bool operator ==(Object other) =>
      other is RemotePlaylistRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// One track from a public Spotify playlist (title/artist metadata only).
class SpotifyPlaylistTrack {
  final String title;
  final String subtitle;
  final int? durationMs;
  final bool isExplicit;
  final String? uri;

  const SpotifyPlaylistTrack({
    required this.title,
    required this.subtitle,
    this.durationMs,
    this.isExplicit = false,
    this.uri,
  });

  /// Artist names as shown by Spotify (`"A, B"`), split and trimmed.
  List<String> get artistNames {
    if (subtitle.trim().isEmpty) return const [];
    return subtitle
        .replaceAll('\u00a0', ' ')
        .split(RegExp(r'\s*,\s*'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  String get primaryArtist => artistNames.isEmpty ? '' : artistNames.first;
}

/// Metadata + tracks scraped from Spotify's public embed page.
class SpotifyPlaylistSnapshot {
  final String id;
  final String name;
  final List<SpotifyPlaylistTrack> tracks;
  final bool truncated;

  const SpotifyPlaylistSnapshot({
    required this.id,
    required this.name,
    required this.tracks,
    this.truncated = false,
  });
}

/// A YouTube Music search hit used to fill a local playlist entry.
class ImportedTrackCandidate {
  final String videoId;
  final String title;
  final String artist;
  final String? artistsJson;
  final int? durationSec;
  final String? thumbnailUrl;
  final bool isExplicit;

  const ImportedTrackCandidate({
    required this.videoId,
    required this.title,
    required this.artist,
    this.artistsJson,
    this.durationSec,
    this.thumbnailUrl,
    this.isExplicit = false,
  });
}

/// Outcome of importing a remote playlist into the local library.
class PlaylistImportResult {
  final int localPlaylistId;
  final String name;
  final PlaylistImportKind source;
  final int importedCount;
  final int skippedCount;

  const PlaylistImportResult({
    required this.localPlaylistId,
    required this.name,
    required this.source,
    required this.importedCount,
    required this.skippedCount,
  });

  int get totalCount => importedCount + skippedCount;
}
