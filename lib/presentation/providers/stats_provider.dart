import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/datasources/local/database.dart';
import 'database_provider.dart';

class ArtistStats {
  final String name;
  final int playCount;
  final String? thumbnailUrl;

  ArtistStats({required this.name, required this.playCount, this.thumbnailUrl});
}

class PodcastStats {
  final String name;
  final int playCount;
  final String? thumbnailUrl;
  final String? podcastBrowseId;

  PodcastStats({
    required this.name,
    required this.playCount,
    this.thumbnailUrl,
    this.podcastBrowseId,
  });
}

class StatsState {
  final bool isLoading;
  final int totalDurationMinutes;
  final int podcastDurationMinutes;
  final List<HistoryData> topSongs;
  final List<ArtistStats> topArtists;
  final List<HistoryData> topEpisodes;
  final List<PodcastStats> topPodcasts;
  final List<int> hourlyDistribution;
  final List<int> weeklyDistribution;
  final bool isWrappedAvailable;

  StatsState({
    this.isLoading = true,
    this.totalDurationMinutes = 0,
    this.podcastDurationMinutes = 0,
    this.topSongs = const [],
    this.topArtists = const [],
    this.topEpisodes = const [],
    this.topPodcasts = const [],
    this.hourlyDistribution = const [],
    this.weeklyDistribution = const [],
    this.isWrappedAvailable = false,
  });

  StatsState copyWith({
    bool? isLoading,
    int? totalDurationMinutes,
    int? podcastDurationMinutes,
    List<HistoryData>? topSongs,
    List<ArtistStats>? topArtists,
    List<HistoryData>? topEpisodes,
    List<PodcastStats>? topPodcasts,
    List<int>? hourlyDistribution,
    List<int>? weeklyDistribution,
    bool? isWrappedAvailable,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      podcastDurationMinutes:
          podcastDurationMinutes ?? this.podcastDurationMinutes,
      topSongs: topSongs ?? this.topSongs,
      topArtists: topArtists ?? this.topArtists,
      topEpisodes: topEpisodes ?? this.topEpisodes,
      topPodcasts: topPodcasts ?? this.topPodcasts,
      hourlyDistribution: hourlyDistribution ?? this.hourlyDistribution,
      weeklyDistribution: weeklyDistribution ?? this.weeklyDistribution,
      isWrappedAvailable: isWrappedAvailable ?? this.isWrappedAvailable,
    );
  }
}

class StatsNotifier extends Notifier<StatsState> {
  StreamSubscription? _historySubscription;

  @override
  StatsState build() {
    final db = ref.watch(databaseProvider);

    // Watch the history table stream to update stats in real time
    final historyStream =
        (db.select(db.history)
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])).watch();

    _historySubscription = historyStream.listen((rows) {
      if (rows.isEmpty) {
        state = StatsState(isLoading: false);
        return;
      }

      // Split rows into music (songs/videos) and podcast episodes.
      final musicRows = rows.where((r) => r.contentType != 'episode').toList();
      final episodeRows =
          rows.where((r) => r.contentType == 'episode').toList();

      // 1. Calculate total duration (in minutes) — across all rows.
      // If duration is null, assume an average track length of 3.5 minutes
      // (210s) for music, or 30 minutes (1800s) for podcast episodes.
      double totalSeconds = 0;
      for (final row in rows) {
        final isEpisode = row.contentType == 'episode';
        final trackDuration = row.duration ?? (isEpisode ? 1800 : 210);
        totalSeconds += trackDuration * row.playCount;
      }
      final totalMinutes = (totalSeconds / 60).round();

      // Podcast-only listening time.
      double podcastSeconds = 0;
      for (final row in episodeRows) {
        final trackDuration = row.duration ?? 1800;
        podcastSeconds += trackDuration * row.playCount;
      }
      final podcastMinutes = (podcastSeconds / 60).round();

      // 2. Calculate Top Songs (sorted by playCount descending) — music only.
      final sortedSongs = List<HistoryData>.from(musicRows)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      final topSongs = sortedSongs.take(5).toList();

      // 3. Calculate Top Artists — music only.
      final artistPlays = <String, int>{};
      final artistThumbnails = <String, String?>{};
      for (final row in musicRows) {
        artistPlays[row.artist] =
            (artistPlays[row.artist] ?? 0) + row.playCount;
        // Keep the latest available thumbnail for the artist
        if (row.thumbnailUrl != null) {
          artistThumbnails[row.artist] = row.thumbnailUrl;
        }
      }

      final topArtists =
          artistPlays.entries
              .map(
                (entry) => ArtistStats(
                  name: entry.key,
                  playCount: entry.value,
                  thumbnailUrl: artistThumbnails[entry.key],
                ),
              )
              .toList()
            ..sort((a, b) => b.playCount.compareTo(a.playCount));

      final top5Artists = topArtists.take(5).toList();

      // 4. Calculate Top Episodes (sorted by playCount descending).
      final sortedEpisodes = List<HistoryData>.from(episodeRows)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      final topEpisodes = sortedEpisodes.take(5).toList();

      // 5. Calculate Top Podcasts — aggregate episodes by podcastBrowseId
      // (falling back to the artist/podcast name when browseId is missing).
      final podcastPlays = <String, int>{};
      final podcastNames = <String, String>{};
      final podcastThumbnails = <String, String?>{};
      final podcastBrowseIds = <String, String?>{};
      for (final row in episodeRows) {
        final key = row.podcastBrowseId ?? row.artist;
        podcastPlays[key] = (podcastPlays[key] ?? 0) + row.playCount;
        podcastNames[key] = row.artist;
        podcastBrowseIds[key] = row.podcastBrowseId;
        if (row.thumbnailUrl != null) {
          podcastThumbnails[key] = row.thumbnailUrl;
        }
      }

      final topPodcasts =
          podcastPlays.entries
              .map(
                (entry) => PodcastStats(
                  name: podcastNames[entry.key] ?? entry.key,
                  playCount: entry.value,
                  thumbnailUrl: podcastThumbnails[entry.key],
                  podcastBrowseId: podcastBrowseIds[entry.key],
                ),
              )
              .toList()
            ..sort((a, b) => b.playCount.compareTo(a.playCount));
      final top5Podcasts = topPodcasts.take(5).toList();

      // 6. Calculate Hourly Distribution (24 hours, based on playedAt and playCount)
      final hourlyDist = List<int>.filled(24, 0);
      for (final row in rows) {
        final hour = row.playedAt.hour;
        if (hour >= 0 && hour < 24) {
          hourlyDist[hour] = hourlyDist[hour] + row.playCount;
        }
      }

      // 7. Calculate Weekly Distribution (7 days, 0 = Monday, 6 = Sunday)
      final weeklyDist = List<int>.filled(7, 0);
      for (final row in rows) {
        final weekday = row.playedAt.weekday; // 1 = Monday, 7 = Sunday
        if (weekday >= 1 && weekday <= 7) {
          weeklyDist[weekday - 1] = weeklyDist[weekday - 1] + row.playCount;
        }
      }

      // 8. Wrapped availability logic: at least 3 distinct songs and total duration >= 5 minutes
      final uniqueSongsCount = musicRows.map((r) => r.videoId).toSet().length;
      final isWrappedAvailable = uniqueSongsCount >= 3 && totalMinutes >= 5;

      state = StatsState(
        isLoading: false,
        totalDurationMinutes: totalMinutes,
        podcastDurationMinutes: podcastMinutes,
        topSongs: topSongs,
        topArtists: top5Artists,
        topEpisodes: topEpisodes,
        topPodcasts: top5Podcasts,
        hourlyDistribution: hourlyDist,
        weeklyDistribution: weeklyDist,
        isWrappedAvailable: isWrappedAvailable,
      );
    });

    ref.onDispose(() {
      _historySubscription?.cancel();
    });

    return StatsState(isLoading: true);
  }
}

final statsProvider = NotifierProvider<StatsNotifier, StatsState>(() {
  return StatsNotifier();
});
