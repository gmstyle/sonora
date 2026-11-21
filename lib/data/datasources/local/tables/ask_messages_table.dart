import 'package:drift/drift.dart';

import 'ask_conversations_table.dart';

@DataClassName('AskMessageRow')
class AskMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(AskConversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get attachmentsJson => text().nullable()();
  TextColumn get toolNamesJson => text().nullable()();
  BoolColumn get isError => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
