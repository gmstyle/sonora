import 'dart:convert';

/// Aggregated facts sent to the cloud LLM for Wrapped narration.
class WrappedFacts {
  const WrappedFacts({
    required this.locale,
    required this.totalMinutes,
    this.podcastMinutes = 0,
    this.topArtistName,
    this.topArtistPlays,
    this.topSongTitle,
    this.topSongArtist,
    this.topSongPlays,
    this.peakHourBand,
    this.peakWeekday,
  });

  final String locale;
  final int totalMinutes;
  final int podcastMinutes;
  final String? topArtistName;
  final int? topArtistPlays;
  final String? topSongTitle;
  final String? topSongArtist;
  final int? topSongPlays;
  final String? peakHourBand;
  final String? peakWeekday;

  String get fingerprint => jsonEncode(toPromptMap());

  Map<String, Object?> toPromptMap() => {
    'locale': locale,
    'totalMinutes': totalMinutes,
    'podcastMinutes': podcastMinutes,
    if (topArtistName != null)
      'topArtist': {'name': topArtistName, 'plays': topArtistPlays},
    if (topSongTitle != null)
      'topSong': {
        'title': topSongTitle,
        'artist': topSongArtist,
        'plays': topSongPlays,
      },
    if (peakHourBand != null) 'peakHourBand': peakHourBand,
    if (peakWeekday != null) 'peakWeekday': peakWeekday,
  };

  /// Allow-listed names the model may cite.
  Set<String> get allowListedNames {
    final names = <String>{};
    if (topArtistName != null && topArtistName!.trim().isNotEmpty) {
      names.add(topArtistName!.trim());
    }
    if (topSongTitle != null && topSongTitle!.trim().isNotEmpty) {
      names.add(topSongTitle!.trim());
    }
    if (topSongArtist != null && topSongArtist!.trim().isNotEmpty) {
      names.add(topSongArtist!.trim());
    }
    return names;
  }

  static String? peakHourBandFrom(List<int> hourly) {
    if (hourly.isEmpty) return null;
    var maxI = 0;
    for (var i = 1; i < hourly.length; i++) {
      if (hourly[i] > hourly[maxI]) maxI = i;
    }
    if (hourly[maxI] <= 0) return null;
    if (maxI >= 5 && maxI <= 11) return 'morning';
    if (maxI >= 12 && maxI <= 16) return 'afternoon';
    if (maxI >= 17 && maxI <= 21) return 'evening';
    return 'night';
  }

  static String? peakWeekdayFrom(List<int> weekly) {
    if (weekly.length < 7) return null;
    var maxI = 0;
    for (var i = 1; i < 7; i++) {
      if (weekly[i] > weekly[maxI]) maxI = i;
    }
    if (weekly[maxI] <= 0) return null;
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[maxI];
  }
}

/// Multi-slide narrator pack from Ask (cloud).
class WrappedNarrative {
  const WrappedNarrative({
    required this.title,
    required this.hook,
    this.artistLine,
    this.songLine,
    required this.closing,
    this.fromAi = true,
  });

  final String title;
  final String hook;
  final String? artistLine;
  final String? songLine;
  final String closing;
  final bool fromAi;
}
