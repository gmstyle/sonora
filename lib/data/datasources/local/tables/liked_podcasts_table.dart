import 'package:drift/drift.dart';

class LikedPodcasts extends Table {
  TextColumn get browseId => text()();
  TextColumn get name => text()();
  TextColumn get authorName => text().nullable()();
  TextColumn get authorId => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get episodeCount => integer().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {browseId};
}
