import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/ask_chat_models.dart';
import '../../../providers/ask_llm_provider.dart';
import '../../../providers/ask_storage_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../library/providers/library_provider.dart';

enum AskUiErrorKind { offline, notConfigured, quotaExceeded, failed }

class AskChatState {
  const AskChatState({
    this.activeConversationId,
    this.isSending = false,
    this.enableWebSearch = false,
    this.errorKind,
  });

  final String? activeConversationId;
  final bool isSending;
  final bool enableWebSearch;
  final AskUiErrorKind? errorKind;

  AskChatState copyWith({
    String? activeConversationId,
    bool clearConversation = false,
    bool? isSending,
    bool? enableWebSearch,
    AskUiErrorKind? errorKind,
    bool clearError = false,
  }) {
    return AskChatState(
      activeConversationId: clearConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      isSending: isSending ?? this.isSending,
      enableWebSearch: enableWebSearch ?? this.enableWebSearch,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
    );
  }
}

class AskChatNotifier extends Notifier<AskChatState> {
  final Random _random = Random();

  @override
  AskChatState build() => const AskChatState();

  void startNewConversation() {
    state = state.copyWith(clearConversation: true, clearError: true);
  }

  void selectConversation(String conversationId) {
    state = state.copyWith(
      activeConversationId: conversationId,
      clearError: true,
    );
  }

  void toggleWebSearch() {
    state = state.copyWith(enableWebSearch: !state.enableWebSearch);
  }

  void clearError() {
    if (state.errorKind == null) return;
    state = state.copyWith(clearError: true);
  }

  Future<void> deleteConversation(String conversationId) async {
    await ref
        .read(askStorageRepositoryProvider)
        .deleteConversation(conversationId);
    if (state.activeConversationId == conversationId) {
      state = state.copyWith(clearConversation: true, clearError: true);
    }
  }

  Future<void> clearAllConversations() async {
    await ref.read(askStorageRepositoryProvider).clearAllConversations();
    state = state.copyWith(clearConversation: true, clearError: true);
  }

  Future<void> openDrop(AskProactiveDrop drop, {required String locale}) async {
    await ref.read(askStorageRepositoryProvider).markDropRead(drop.id);
    startNewConversation();
    await sendMessage(drop.starterPrompt, locale: locale);
  }

  Future<void> sendMessage(String rawText, {required String locale}) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isSending) return;

    if (ref.read(isOfflineProvider)) {
      state = state.copyWith(errorKind: AskUiErrorKind.offline);
      return;
    }

    final caps = await ref.read(askCapabilitiesProvider.future);
    if (!caps.isConfigured) {
      state = state.copyWith(errorKind: AskUiErrorKind.notConfigured);
      return;
    }
    if (!caps.canUseAsk) {
      state = state.copyWith(errorKind: AskUiErrorKind.offline);
      return;
    }

    final storage = ref.read(askStorageRepositoryProvider);
    final now = DateTime.now();
    var convId = state.activeConversationId;
    if (convId == null) {
      convId = _newId('conv');
      final title = text.length > 48
          ? '${text.substring(0, 48).trim()}…'
          : text;
      await storage.upsertConversation(
        AskConversationSummary(
          id: convId,
          title: title,
          createdAt: now,
          updatedAt: now,
        ),
      );
      state = state.copyWith(activeConversationId: convId);
    } else {
      final existing = await storage.getConversations();
      final match = existing.cast<AskConversationSummary?>().firstWhere(
        (c) => c?.id == convId,
        orElse: () => null,
      );
      await storage.upsertConversation(
        AskConversationSummary(
          id: convId,
          title:
              match?.title ??
              (text.length > 48 ? '${text.substring(0, 48).trim()}…' : text),
          createdAt: match?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    final history = await storage.getMessages(convId);
    final userMsg = AskChatMessage(
      id: _newId('msg'),
      conversationId: convId,
      role: 'user',
      content: text,
      createdAt: now,
    );
    await storage.insertMessage(userMsg);

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final result = await ref
          .read(askAgentUseCaseProvider)
          .execute(
            userMessage: text,
            executor: createAskToolExecutor(ref),
            history: history,
            locale: locale,
            enableWebSearch: state.enableWebSearch,
          );

      final attachments = List<AskAttachment>.from(result.attachments);
      if (result.sources.isNotEmpty &&
          !attachments.any((a) => a is AskInsightsAttachment)) {
        attachments.add(
          AskInsightsAttachment(
            title: '',
            bullets: const [],
            sources: result.sources,
          ),
        );
      }

      if (result.assistantText.trim().isEmpty && attachments.isEmpty) {
        state = state.copyWith(
          isSending: false,
          errorKind: AskUiErrorKind.failed,
        );
        return;
      }

      final assistantTime = DateTime.now();
      await storage.insertMessage(
        AskChatMessage(
          id: _newId('msg'),
          conversationId: convId,
          role: 'assistant',
          content: result.assistantText,
          attachments: attachments,
          toolNamesUsed: result.toolNamesUsed,
          createdAt: assistantTime,
        ),
      );

      final convs = await storage.getConversations();
      final current = convs.cast<AskConversationSummary?>().firstWhere(
        (c) => c?.id == convId,
        orElse: () => null,
      );
      if (current != null) {
        await storage.upsertConversation(
          AskConversationSummary(
            id: current.id,
            title: current.title,
            createdAt: current.createdAt,
            updatedAt: assistantTime,
          ),
        );
      }

      state = state.copyWith(isSending: false, clearError: true);
    } on AskQuotaExceededException {
      state = state.copyWith(
        isSending: false,
        errorKind: AskUiErrorKind.quotaExceeded,
      );
    } on AskNotConfiguredException {
      state = state.copyWith(
        isSending: false,
        errorKind: AskUiErrorKind.notConfigured,
      );
    } catch (e) {
      debugPrint('Sonora Ask chat turn failed: $e');
      state = state.copyWith(
        isSending: false,
        errorKind: AskUiErrorKind.failed,
      );
    }
  }

  Future<int?> confirmPlaylistProposal({
    required AskChatMessage message,
    required int attachmentIndex,
  }) async {
    final target = message.attachments[attachmentIndex];
    if (target is! AskPlaylistWriteProposal) return null;

    final savedId = await ref
        .read(applyAskPlaylistWriteUseCaseProvider)
        .execute(target);
    final updated = List<AskAttachment>.from(message.attachments);
    updated[attachmentIndex] = target.copyWith(
      status: 'saved',
      savedPlaylistId: savedId,
    );
    await ref
        .read(askStorageRepositoryProvider)
        .updateMessageAttachments(message.id, updated);
    ref.invalidate(playlistsProvider);
    return savedId;
  }

  Future<void> discardPlaylistProposal({
    required AskChatMessage message,
    required int attachmentIndex,
  }) async {
    final target = message.attachments[attachmentIndex];
    if (target is! AskPlaylistWriteProposal) return;

    final updated = List<AskAttachment>.from(message.attachments);
    updated[attachmentIndex] = target.copyWith(status: 'discarded');
    await ref
        .read(askStorageRepositoryProvider)
        .updateMessageAttachments(message.id, updated);
  }

  Future<int?> confirmSaveMix({
    required AskChatMessage message,
    required int attachmentIndex,
    String? customName,
  }) async {
    final target = message.attachments[attachmentIndex];
    if (target is! AskMixAttachment) return null;

    final savedId = await ref
        .read(applyAskPlaylistWriteUseCaseProvider)
        .saveMixAsPlaylist(target, customName: customName);
    final updated = List<AskAttachment>.from(message.attachments);
    updated[attachmentIndex] = target.copyWith(savedPlaylistId: savedId);
    await ref
        .read(askStorageRepositoryProvider)
        .updateMessageAttachments(message.id, updated);
    ref.invalidate(playlistsProvider);
    return savedId;
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(9999)}';
}

final askChatProvider = NotifierProvider<AskChatNotifier, AskChatState>(
  AskChatNotifier.new,
);

/// Number of unread active Pulse Drops (renders a subtle dot on the Ask tab).
final askUnreadDropsCountProvider = Provider<int>((ref) {
  final drops = ref.watch(askActiveDropsProvider).asData?.value ?? const [];
  return drops.where((d) => !d.isRead).length;
});
