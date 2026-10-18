/// Structured intent produced by the on-device LLM for Ask search / Mix.
///
/// Field names stay English so parsing does not depend on the user's query
/// language. Never contains catalog IDs — Sonora resolves via history or YTM.
class MusicSearchIntent {
  const MusicSearchIntent({
    required this.searchQuery,
    this.mood,
    this.genres = const [],
    this.era,
    this.seedArtists = const [],
    this.contentType = MusicSearchContentType.any,
    this.source = MixSource.both,
    this.energy = MixEnergy.unknown,
  });

  /// Keyword query to send to YouTube Music search.
  final String searchQuery;
  final String? mood;
  final List<String> genres;
  final String? era;
  final List<String> seedArtists;
  final MusicSearchContentType contentType;

  /// Where to assemble a moment mix from.
  final MixSource source;

  /// Relative energy for ranking / UI label (mix path).
  final MixEnergy energy;

  /// Normalized mood for l10n labels (never LLM prose).
  MixMood get mixMood => MixMood.parse(mood);

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

/// Catalog / library source for assembling a moment mix.
enum MixSource {
  history,
  ytm,
  both;

  static MixSource parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'history':
      case 'liked':
      case 'library':
      case 'local':
        return MixSource.history;
      case 'ytm':
      case 'youtube':
      case 'search':
      case 'catalog':
        return MixSource.ytm;
      case 'both':
      case 'all':
      case 'mixed':
        return MixSource.both;
      default:
        return MixSource.both;
    }
  }
}

/// Relative energy used for mix ranking and l10n labels.
enum MixEnergy {
  low,
  medium,
  high,
  unknown;

  static MixEnergy parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'low':
      case 'calm':
      case 'chill':
      case 'soft':
      case 'quiet':
        return MixEnergy.low;
      case 'medium':
      case 'mid':
      case 'moderate':
        return MixEnergy.medium;
      case 'high':
      case 'energetic':
      case 'upbeat':
      case 'intense':
        return MixEnergy.high;
      default:
        return MixEnergy.unknown;
    }
  }
}

/// Closed mood set for mix card titles (mapped to ARB keys in the UI).
enum MixMood {
  calm,
  energetic,
  focus,
  happy,
  melancholic,
  romantic,
  workout,
  party,
  chill,
  unknown;

  static MixMood parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'calm':
      case 'relax':
      case 'relaxed':
      case 'peaceful':
      case 'serene':
        return MixMood.calm;
      case 'energetic':
      case 'energy':
      case 'upbeat':
      case 'hype':
        return MixMood.energetic;
      case 'focus':
      case 'concentrate':
      case 'study':
      case 'work':
        return MixMood.focus;
      case 'happy':
      case 'joyful':
      case 'uplifting':
      case 'feel-good':
      case 'feelgood':
        return MixMood.happy;
      case 'melancholic':
      case 'sad':
      case 'melancholy':
      case 'blue':
        return MixMood.melancholic;
      case 'romantic':
      case 'love':
      case 'intimate':
        return MixMood.romantic;
      case 'workout':
      case 'gym':
      case 'running':
      case 'run':
      case 'training':
        return MixMood.workout;
      case 'party':
      case 'dance':
      case 'club':
        return MixMood.party;
      case 'chill':
      case 'lofi':
      case 'lo-fi':
      case 'ambient':
        return MixMood.chill;
      default:
        return MixMood.unknown;
    }
  }
}
