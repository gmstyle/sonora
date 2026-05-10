import 'package:drift/drift.dart';

class FollowedArtists extends Table {
  TextColumn get artistId => text()();
  TextColumn get name => text()();
  TextColumn get thumbnailUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {artistId};
}
