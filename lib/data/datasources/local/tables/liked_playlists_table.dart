import 'package:drift/drift.dart';

class LikedPlaylists extends Table {
  TextColumn get playlistId => text()();
  TextColumn get name => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get videoCount => integer().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId};
}
