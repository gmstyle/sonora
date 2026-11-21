import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/ask_chat_models.dart';
import '../../domain/repositories/ask_storage_repository.dart';
import '../datasources/local/daos/ask_dao.dart';
import '../datasources/local/database.dart';

class AskStorageRepositoryImpl implements AskStorageRepository {
  AskStorageRepositoryImpl(AppDatabase db) : _dao = AskDao(db);

  final AskDao _dao;

  @override
  Stream<List<AskConversationSummary>> watchConversations() {
    return _dao.watchConversations().map(
      (rows) => rows.map(_mapConversation).toList(growable: false),
    );
  }

  @override
  Future<List<AskConversationSummary>> getConversations() async {
    final rows = await _dao.getConversations();
    return rows.map(_mapConversation).toList(growable: false);
  }

  @override
  Future<void> upsertConversation(AskConversationSummary conversation) {
    return _dao.upsertConversation(
      AskConversationsCompanion(
        id: Value(conversation.id),
        title: Value(conversation.title),
        createdAt: Value(conversation.createdAt),
        updatedAt: Value(conversation.updatedAt),
      ),
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) {
    return _dao.deleteConversation(conversationId);
  }

  @override
  Future<void> clearAllConversations() {
    return _dao.clearAllConversations();
  }

  @override
  Stream<List<AskChatMessage>> watchMessages(String conversationId) {
    return _dao
        .watchMessages(conversationId)
        .map((rows) => rows.map(_mapMessage).toList(growable: false));
  }

  @override
  Future<List<AskChatMessage>> getMessages(String conversationId) async {
    final rows = await _dao.getMessages(conversationId);
    return rows.map(_mapMessage).toList(growable: false);
  }

  @override
  Future<void> insertMessage(AskChatMessage message) {
    final encodedTools = message.toolNamesUsed.isEmpty
        ? null
        : jsonEncode(message.toolNamesUsed);
    return _dao.insertMessage(
      AskMessagesCompanion(
        id: Value(message.id),
        conversationId: Value(message.conversationId),
        role: Value(message.role),
        content: Value(message.content),
        attachmentsJson: Value(AskAttachment.encodeList(message.attachments)),
        toolNamesJson: Value(encodedTools),
        isError: Value(message.isError),
        createdAt: Value(message.createdAt),
      ),
    );
  }

  @override
  Future<void> updateMessageAttachments(
    String messageId,
    List<AskAttachment> attachments,
  ) {
    return _dao.updateMessageAttachments(
      messageId,
      AskAttachment.encodeList(attachments),
    );
  }

  @override
  Stream<List<AskProactiveDrop>> watchActiveDrops() {
    return _dao.watchActiveDrops().map(
      (rows) => rows.map(_mapDrop).toList(growable: false),
    );
  }

  @override
  Future<List<AskProactiveDrop>> getActiveDrops() async {
    final rows = await _dao.getActiveDrops();
    return rows.map(_mapDrop).toList(growable: false);
  }

  @override
  Future<void> upsertDrop(AskProactiveDrop drop) {
    return _dao.upsertDrop(
      AskProactiveDropsCompanion(
        id: Value(drop.id),
        kind: Value(drop.kind),
        title: Value(drop.title),
        body: Value(drop.body),
        starterPrompt: Value(drop.starterPrompt),
        seedId: Value(drop.seedId),
        createdAt: Value(drop.createdAt),
        readAt: Value(drop.readAt),
        dismissedAt: Value(drop.dismissedAt),
      ),
    );
  }

  @override
  Future<void> markDropRead(String dropId) {
    return _dao.markDropRead(dropId, DateTime.now());
  }

  @override
  Future<void> dismissDrop(String dropId) {
    return _dao.dismissDrop(dropId, DateTime.now());
  }

  static AskConversationSummary _mapConversation(AskConversationRow row) {
    return AskConversationSummary(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static AskChatMessage _mapMessage(AskMessageRow row) {
    var tools = const <String>[];
    final rawTools = row.toolNamesJson;
    if (rawTools != null && rawTools.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTools);
        if (decoded is List) {
          tools = decoded.map((e) => e.toString()).toList(growable: false);
        }
      } catch (_) {
        tools = const <String>[];
      }
    }
    return AskChatMessage(
      id: row.id,
      conversationId: row.conversationId,
      role: row.role,
      content: row.content,
      attachments: AskAttachment.decodeList(row.attachmentsJson),
      toolNamesUsed: tools,
      isError: row.isError,
      createdAt: row.createdAt,
    );
  }

  static AskProactiveDrop _mapDrop(AskProactiveDropRow row) {
    return AskProactiveDrop(
      id: row.id,
      kind: row.kind,
      title: row.title,
      body: row.body,
      starterPrompt: row.starterPrompt,
      seedId: row.seedId,
      createdAt: row.createdAt,
      readAt: row.readAt,
      dismissedAt: row.dismissedAt,
    );
  }
}
