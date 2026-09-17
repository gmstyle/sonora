import 'package:drift/drift.dart';

class Downloads extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get artist => text().nullable()();

  /// JSON array of credited artists when length > 1; null for single-artist rows.
  TextColumn get artistsJson => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  TextColumn get status => text()();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();
  BoolColumn get isExplicit => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {videoId};
}
