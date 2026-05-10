import 'package:drift/drift.dart';
import '../database.dart';

class DownloadsDao extends DatabaseAccessor<AppDatabase> {
  DownloadsDao(super.db);

  Future<List<Download>> getAllDownloads() => select(db.downloads).get();

  Future<Download?> getDownload(String videoId) =>
      (select(db.downloads)..where((t) => t.videoId.equals(videoId)))
          .getSingleOrNull();

  Future<void> insertDownload(DownloadsCompanion entry) =>
      into(db.downloads).insertOnConflictUpdate(entry);

  Future<void> updateStatus(String videoId, String status) =>
      (update(db.downloads)..where((t) => t.videoId.equals(videoId)))
          .write(DownloadsCompanion(status: Value(status)));

  Future<void> deleteDownload(String videoId) =>
      (delete(db.downloads)..where((t) => t.videoId.equals(videoId))).go();
}
