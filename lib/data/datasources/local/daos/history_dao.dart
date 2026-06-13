import 'package:drift/drift.dart';
import '../database.dart';

class HistoryDao extends DatabaseAccessor<AppDatabase> {
  HistoryDao(super.db);

  Future<List<HistoryData>> getRecentHistory({int limit = 50}) async {
    // Over-fetch to account for any pre-existing duplicates, then deduplicate
    // in Dart keeping the most-recently-played row per videoId.
    final rows =
        await (select(db.history)
              ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
              ..limit(limit * 3))
            .get();
    final seen = <String>{};
    return rows.where((r) => seen.add(r.videoId)).take(limit).toList();
  }

  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    bool isVideo = false,
  }) async {
    // Fetch ALL rows for this videoId (oldest bug may have produced duplicates).
    final all =
        await (select(db.history)
              ..where((t) => t.videoId.equals(videoId))
              ..orderBy([(t) => OrderingTerm.desc(t.playedAt)]))
            .get();

    if (all.isNotEmpty) {
      final latest = all.first;
      // Delete any stale duplicates (keep only the most recent one).
      for (final dup in all.skip(1)) {
        await (delete(db.history)..where((t) => t.id.equals(dup.id))).go();
      }
      await (update(db.history)..where((t) => t.id.equals(latest.id))).write(
        HistoryCompanion(
          playedAt: Value(DateTime.now()),
          playCount: Value(latest.playCount + 1),
          thumbnailUrl: Value(thumbnailUrl ?? latest.thumbnailUrl),
          isVideo: Value(isVideo),
        ),
      );
    } else {
      await into(db.history).insert(
        HistoryCompanion(
          videoId: Value(videoId),
          title: Value(title),
          artist: Value(artist),
          thumbnailUrl: Value(thumbnailUrl),
          playedAt: Value(DateTime.now()),
          playCount: const Value(1),
          isVideo: Value(isVideo),
        ),
      );
    }
  }

  Future<void> clearHistory() => delete(db.history).go();

  Future<void> insertSearchEntry(String query) => into(db.searchHistory).insert(
    SearchHistoryCompanion(
      query: Value(query),
      searchedAt: Value(DateTime.now()),
    ),
  );

  Future<List<SearchHistoryData>> getRecentSearches({int limit = 10}) =>
      (select(db.searchHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])
            ..limit(limit))
          .get();

  Future<void> clearSearchHistory() => delete(db.searchHistory).go();

  Future<void> insertHistoryRaw(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    required DateTime playedAt,
    int playCount = 1,
    bool isVideo = false,
  }) => into(db.history).insert(
    HistoryCompanion(
      videoId: Value(videoId),
      title: Value(title),
      artist: Value(artist),
      thumbnailUrl: Value(thumbnailUrl),
      playedAt: Value(playedAt),
      playCount: Value(playCount),
      isVideo: Value(isVideo),
    ),
  );

  Future<void> insertSearchEntryRaw(
    String query, {
    required DateTime searchedAt,
  }) => into(db.searchHistory).insert(
    SearchHistoryCompanion(query: Value(query), searchedAt: Value(searchedAt)),
  );
}
