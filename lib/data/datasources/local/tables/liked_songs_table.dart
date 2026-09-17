import 'package:drift/drift.dart';

class LikedSongs extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get albumId => text().nullable()();
  /// JSON array of credited artists when length > 1; null for single-artist rows.
  TextColumn get artistsJson => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();
  IntColumn get duration => integer().nullable()();
  BoolColumn get isExplicit => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {videoId};
}
