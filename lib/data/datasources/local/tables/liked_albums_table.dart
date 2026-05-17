import 'package:drift/drift.dart';

class LikedAlbums extends Table {
  TextColumn get albumId => text()();
  TextColumn get name => text()();
  TextColumn get artistName => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get year => integer().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {albumId};
}
