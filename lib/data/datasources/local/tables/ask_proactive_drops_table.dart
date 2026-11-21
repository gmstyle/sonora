import 'package:drift/drift.dart';

@DataClassName('AskProactiveDropRow')
class AskProactiveDrops extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get starterPrompt => text()();
  TextColumn get seedId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get dismissedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
