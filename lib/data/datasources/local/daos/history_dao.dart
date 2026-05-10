import 'package:drift/drift.dart';
import '../database.dart';

class HistoryDao extends DatabaseAccessor<AppDatabase> {
  HistoryDao(super.db);

  Future<List<HistoryData>> getRecentHistory({int limit = 50}) =>
      (select(db.history)
            ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
            ..limit(limit))
          .get();

  Future<void> recordPlay(String videoId, String title, String artist) async {
    final existing = await (select(db.history)
          ..where((t) => t.videoId.equals(videoId))
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (update(db.history)..where((t) => t.id.equals(existing.id)))
          .write(HistoryCompanion(
        playedAt: Value(DateTime.now()),
        playCount: Value(existing.playCount + 1),
      ));
    } else {
      await into(db.history).insert(HistoryCompanion(
        videoId: Value(videoId),
        title: Value(title),
        artist: Value(artist),
        playedAt: Value(DateTime.now()),
        playCount: const Value(1),
      ));
    }
  }

  Future<void> clearHistory() => delete(db.history).go();

  Future<void> insertSearchEntry(String query) =>
      into(db.searchHistory).insert(SearchHistoryCompanion(
        query: Value(query),
        searchedAt: Value(DateTime.now()),
      ));

  Future<List<SearchHistoryData>> getRecentSearches({int limit = 10}) =>
      (select(db.searchHistory)
            ..orderBy([(t) => OrderingTerm.desc(t.searchedAt)])
            ..limit(limit))
          .get();

  Future<void> clearSearchHistory() => delete(db.searchHistory).go();
}
