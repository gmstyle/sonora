import '../models/ask_chat_models.dart';

abstract class AskStorageRepository {
  Stream<List<AskConversationSummary>> watchConversations();
  Future<List<AskConversationSummary>> getConversations();
  Future<void> upsertConversation(AskConversationSummary conversation);
  Future<void> deleteConversation(String conversationId);
  Future<void> clearAllConversations();

  Stream<List<AskChatMessage>> watchMessages(String conversationId);
  Future<List<AskChatMessage>> getMessages(String conversationId);
  Future<void> insertMessage(AskChatMessage message);
  Future<void> deleteMessage(String messageId);
  Future<void> updateMessageAttachments(
    String messageId,
    List<AskAttachment> attachments,
  );

  Stream<List<AskProactiveDrop>> watchActiveDrops();
  Future<List<AskProactiveDrop>> getActiveDrops();
  Future<List<AskProactiveDrop>> getRecentDrops({int limit = 100});
  Future<void> upsertDrop(AskProactiveDrop drop);
  Future<void> markDropRead(String dropId);
  Future<void> dismissDrop(String dropId);
}
