import 'package:drift/drift.dart';

class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();
}
