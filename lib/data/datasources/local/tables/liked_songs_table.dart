import 'package:drift/drift.dart';

class LikedSongs extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get albumId => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {videoId};
}
