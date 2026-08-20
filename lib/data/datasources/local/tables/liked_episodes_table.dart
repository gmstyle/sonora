import 'package:drift/drift.dart';

class LikedEpisodes extends Table {
  TextColumn get videoId => text()();
  TextColumn get browseId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get podcastName => text().nullable()();
  TextColumn get podcastBrowseId => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get date => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {videoId};
}
