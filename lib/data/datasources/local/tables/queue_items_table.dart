import 'package:drift/drift.dart';

class QueueItems extends Table {
  IntColumn get position => integer()();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get albumTitle => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationSec => integer().nullable()();
  BoolColumn get isVideo => boolean()();

  @override
  Set<Column> get primaryKey => {position};
}
