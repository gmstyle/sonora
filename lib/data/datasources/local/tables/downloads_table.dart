import 'package:drift/drift.dart';

class Downloads extends Table {
  TextColumn get videoId => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {videoId};
}
