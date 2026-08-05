import 'package:drift/drift.dart';
import '../database.dart';

class DownloadsDao extends DatabaseAccessor<AppDatabase> {
  DownloadsDao(super.db);

  Future<List<Download>> getAllDownloads() => select(db.downloads).get();

  Stream<List<Download>> watchCompletedDownloads() {
    return (select(db.downloads)
          ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm.desc(t.downloadedAt)]))
        .watch();
  }

  Future<Download?> getDownload(String videoId) =>
      (select(db.downloads)
        ..where((t) => t.videoId.equals(videoId))).getSingleOrNull();

  Future<void> insertDownload(DownloadsCompanion entry) =>
      into(db.downloads).insertOnConflictUpdate(entry);

  Future<void> updateStatus(String videoId, String status) =>
      (update(db.downloads)..where(
        (t) => t.videoId.equals(videoId),
      )).write(DownloadsCompanion(status: Value(status)));

  Future<List<Download>> getIncompleteDownloads() {
    return (select(db.downloads)
      ..where((t) => t.status.equals('completed').not())).get();
  }

  Future<int> deleteIncompleteDownloads() {
    return (delete(db.downloads)
      ..where((t) => t.status.equals('completed').not())).go();
  }

  Future<void> deleteDownload(String videoId) =>
      (delete(db.downloads)..where((t) => t.videoId.equals(videoId))).go();
}
