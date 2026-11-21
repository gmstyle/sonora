import 'package:drift/drift.dart';

import '../database.dart';

class AskDao extends DatabaseAccessor<AppDatabase> {
  AskDao(super.db);

  Stream<List<AskConversationRow>> watchConversations() {
    return (select(
      db.askConversations,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<List<AskConversationRow>> getConversations() {
    return (select(
      db.askConversations,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Future<void> upsertConversation(AskConversationsCompanion entry) {
    return into(db.askConversations).insertOnConflictUpdate(entry);
  }

  Future<void> deleteConversation(String conversationId) async {
    await transaction(() async {
      await (delete(
        db.askMessages,
      )..where((t) => t.conversationId.equals(conversationId))).go();
      await (delete(
        db.askConversations,
      )..where((t) => t.id.equals(conversationId))).go();
    });
  }

  Future<void> clearAllConversations() async {
    await transaction(() async {
      await delete(db.askMessages).go();
      await delete(db.askConversations).go();
    });
  }

  Stream<List<AskMessageRow>> watchMessages(String conversationId) {
    return (select(db.askMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<AskMessageRow>> getMessages(String conversationId) {
    return (select(db.askMessages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> insertMessage(AskMessagesCompanion entry) {
    return into(db.askMessages).insertOnConflictUpdate(entry);
  }

  Future<void> updateMessageAttachments(
    String messageId,
    String? attachmentsJson,
  ) {
    return (update(db.askMessages)..where((t) => t.id.equals(messageId))).write(
      AskMessagesCompanion(attachmentsJson: Value(attachmentsJson)),
    );
  }

  Stream<List<AskProactiveDropRow>> watchActiveDrops() {
    return (select(db.askProactiveDrops)
          ..where((t) => t.dismissedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<AskProactiveDropRow>> getActiveDrops() {
    return (select(db.askProactiveDrops)
          ..where((t) => t.dismissedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> upsertDrop(AskProactiveDropsCompanion entry) {
    return into(db.askProactiveDrops).insertOnConflictUpdate(entry);
  }

  Future<void> markDropRead(String dropId, DateTime readAt) {
    return (update(db.askProactiveDrops)..where((t) => t.id.equals(dropId)))
        .write(AskProactiveDropsCompanion(readAt: Value(readAt)));
  }

  Future<void> dismissDrop(String dropId, DateTime dismissedAt) {
    return (update(db.askProactiveDrops)..where((t) => t.id.equals(dropId)))
        .write(AskProactiveDropsCompanion(dismissedAt: Value(dismissedAt)));
  }
}
