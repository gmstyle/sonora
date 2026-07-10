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

class StatsState {
  final bool isLoading;
  final int totalDurationMinutes;
  final List<HistoryData> topSongs;
  final List<ArtistStats> topArtists;
  final List<int> hourlyDistribution;
  final List<int> weeklyDistribution;
  final bool isWrappedAvailable;

  StatsState({
    this.isLoading = true,
    this.totalDurationMinutes = 0,
    this.topSongs = const [],
    this.topArtists = const [],
    this.hourlyDistribution = const [],
    this.weeklyDistribution = const [],
    this.isWrappedAvailable = false,
  });

  StatsState copyWith({
    bool? isLoading,
    int? totalDurationMinutes,
    List<HistoryData>? topSongs,
    List<ArtistStats>? topArtists,
    List<int>? hourlyDistribution,
    List<int>? weeklyDistribution,
    bool? isWrappedAvailable,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      topSongs: topSongs ?? this.topSongs,
      topArtists: topArtists ?? this.topArtists,
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

      // 1. Calculate total duration (in minutes)
      // If duration is null, we assume an average track length of 3.5 minutes (210 seconds)
      double totalSeconds = 0;
      for (final row in rows) {
        final trackDuration = row.duration ?? 210;
        totalSeconds += trackDuration * row.playCount;
      }
      final totalMinutes = (totalSeconds / 60).round();

      // 2. Calculate Top Songs (sorted by playCount descending)
      final sortedSongs = List<HistoryData>.from(rows)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      final topSongs = sortedSongs.take(5).toList();

      // 3. Calculate Top Artists
      final artistPlays = <String, int>{};
      final artistThumbnails = <String, String?>{};
      for (final row in rows) {
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

      // 4. Calculate Hourly Distribution (24 hours, based on playedAt and playCount)
      final hourlyDist = List<int>.filled(24, 0);
      for (final row in rows) {
        final hour = row.playedAt.hour;
        if (hour >= 0 && hour < 24) {
          hourlyDist[hour] = hourlyDist[hour] + row.playCount;
        }
      }

      // 5. Calculate Weekly Distribution (7 days, 0 = Monday, 6 = Sunday)
      final weeklyDist = List<int>.filled(7, 0);
      for (final row in rows) {
        final weekday = row.playedAt.weekday; // 1 = Monday, 7 = Sunday
        if (weekday >= 1 && weekday <= 7) {
          weeklyDist[weekday - 1] = weeklyDist[weekday - 1] + row.playCount;
        }
      }

      // 6. Wrapped availability logic: at least 3 distinct songs and total duration >= 5 minutes
      final uniqueSongsCount = rows.map((r) => r.videoId).toSet().length;
      final isWrappedAvailable = uniqueSongsCount >= 3 && totalMinutes >= 5;

      state = StatsState(
        isLoading: false,
        totalDurationMinutes: totalMinutes,
        topSongs: topSongs,
        topArtists: top5Artists,
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
