import 'package:drift/drift.dart';

class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  DateTimeColumn get playedAt => dateTime()();
  IntColumn get playCount => integer()();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();
  IntColumn get duration => integer().nullable()();
}
