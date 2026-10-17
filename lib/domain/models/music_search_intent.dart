/// Structured intent produced by the on-device LLM for Ask search.
///
/// Field names stay English so parsing does not depend on the user's query
/// language. Never contains catalog IDs — Sonora resolves via YTM search.
class MusicSearchIntent {
  const MusicSearchIntent({
    required this.searchQuery,
    this.mood,
    this.genres = const [],
    this.era,
    this.seedArtists = const [],
    this.contentType = MusicSearchContentType.any,
  });

  /// Keyword query to send to YouTube Music search.
  final String searchQuery;
  final String? mood;
  final List<String> genres;
  final String? era;
  final List<String> seedArtists;
  final MusicSearchContentType contentType;

  /// Short human-readable summary for the "Interpreted as…" banner.
  String get displayLabel {
    final parts = <String>[
      if (mood != null && mood!.trim().isNotEmpty) mood!.trim(),
      ...genres.map((g) => g.trim()).where((g) => g.isNotEmpty),
      if (era != null && era!.trim().isNotEmpty) era!.trim(),
      ...seedArtists.map((a) => a.trim()).where((a) => a.isNotEmpty),
    ];
    if (parts.isEmpty) return searchQuery;
    return parts.join(' · ');
  }

  /// Maps content type to the Search filter index used by [searchFilterProvider].
  int get searchFilterIndex => switch (contentType) {
    MusicSearchContentType.songs => 1,
    MusicSearchContentType.artists => 2,
    MusicSearchContentType.albums => 3,
    MusicSearchContentType.playlists => 4,
    MusicSearchContentType.podcasts => 5,
    MusicSearchContentType.episodes => 6,
    MusicSearchContentType.any => 0,
  };
}

enum MusicSearchContentType {
  any,
  songs,
  artists,
  albums,
  playlists,
  podcasts,
  episodes,
}
