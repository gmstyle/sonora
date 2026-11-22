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
    this.progressPhase,
    this.retryPrompt,
    this.retryMessageId,
  });

  final String? activeConversationId;
  final bool isSending;
  final bool enableWebSearch;
  final AskUiErrorKind? errorKind;
  final AskProgressPhase? progressPhase;
  final String? retryPrompt;
  final String? retryMessageId;

  bool get canRetry => errorKind != null && retryPrompt != null && !isSending;

  AskChatState copyWith({
    String? activeConversationId,
    bool clearConversation = false,
    bool? isSending,
    bool? enableWebSearch,
    AskUiErrorKind? errorKind,
    bool clearError = false,
    AskProgressPhase? progressPhase,
    bool clearProgress = false,
    String? retryPrompt,
    String? retryMessageId,
    bool clearRetry = false,
  }) {
    return AskChatState(
      activeConversationId: clearConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      isSending: isSending ?? this.isSending,
      enableWebSearch: enableWebSearch ?? this.enableWebSearch,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      progressPhase: clearProgress
          ? null
          : (progressPhase ?? this.progressPhase),
      retryPrompt: clearRetry ? null : (retryPrompt ?? this.retryPrompt),
      retryMessageId: clearRetry
          ? null
          : (retryMessageId ?? this.retryMessageId),
    );
  }
}

class AskChatNotifier extends Notifier<AskChatState> {
  final Random _random = Random();
  int _activeRequestId = 0;

  @override
  AskChatState build() {
    ref.onDispose(() {
      _activeRequestId++;
    });
    return const AskChatState();
  }

  void startNewConversation() {
    _activeRequestId++;
    state = state.copyWith(
      clearConversation: true,
      isSending: false,
      clearProgress: true,
      clearError: true,
      clearRetry: true,
    );
  }

  void selectConversation(String conversationId) {
    _activeRequestId++;
    state = state.copyWith(
      activeConversationId: conversationId,
      isSending: false,
      clearProgress: true,
      clearError: true,
      clearRetry: true,
    );
  }

  void toggleWebSearch() {
    state = state.copyWith(enableWebSearch: !state.enableWebSearch);
  }

  void cancelActiveRequest() {
    if (!state.isSending) return;
    _activeRequestId++;
    state = state.copyWith(isSending: false, clearProgress: true);
  }

  void clearError() {
    if (state.errorKind == null && state.retryPrompt == null) return;
    state = state.copyWith(clearError: true, clearRetry: true);
  }

  Future<void> deleteConversation(String conversationId) async {
    await ref
        .read(askStorageRepositoryProvider)
        .deleteConversation(conversationId);
    if (state.activeConversationId == conversationId) {
      _activeRequestId++;
      state = state.copyWith(
        clearConversation: true,
        isSending: false,
        clearProgress: true,
        clearError: true,
        clearRetry: true,
      );
    }
  }

  Future<void> clearAllConversations() async {
    _activeRequestId++;
    await ref.read(askStorageRepositoryProvider).clearAllConversations();
    state = state.copyWith(
      clearConversation: true,
      isSending: false,
      clearProgress: true,
      clearError: true,
      clearRetry: true,
    );
  }

  Future<void> openDrop(AskProactiveDrop drop, {required String locale}) async {
    await ref.read(askStorageRepositoryProvider).markDropRead(drop.id);
    startNewConversation();
    await sendMessage(drop.starterPrompt, locale: locale);
  }

  Future<bool> _ensurePreflightReady() async {
    if (ref.read(isOfflineProvider)) {
      state = state.copyWith(errorKind: AskUiErrorKind.offline);
      return false;
    }

    final caps = await ref.read(askCapabilitiesProvider.future);
    if (!caps.isConfigured) {
      state = state.copyWith(errorKind: AskUiErrorKind.notConfigured);
      return false;
    }
    if (!caps.canUseAsk) {
      state = state.copyWith(errorKind: AskUiErrorKind.offline);
      return false;
    }
    return true;
  }

  Future<void> sendMessage(String rawText, {required String locale}) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isSending) return;
    if (!await _ensurePreflightReady()) return;

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
    final userMsgId = _newId('msg');
    final userMsg = AskChatMessage(
      id: userMsgId,
      conversationId: convId,
      role: 'user',
      content: text,
      createdAt: now,
    );
    await storage.insertMessage(userMsg);

    await _executeAgentTurn(
      convId: convId,
      userMessageId: userMsgId,
      text: text,
      history: history,
      locale: locale,
    );
  }

  Future<void> retryLastFailed({required String locale}) async {
    final prompt = state.retryPrompt?.trim() ?? '';
    final convId = state.activeConversationId;
    if (prompt.isEmpty || convId == null || state.isSending) return;
    if (!await _ensurePreflightReady()) return;

    final storage = ref.read(askStorageRepositoryProvider);
    final messages = await storage.getMessages(convId);
    final retryMsgId = state.retryMessageId;
    final history = retryMsgId == null
        ? messages
        : messages.where((m) => m.id != retryMsgId).toList(growable: false);

    await _executeAgentTurn(
      convId: convId,
      userMessageId: retryMsgId,
      text: prompt,
      history: history,
      locale: locale,
    );
  }

  Future<void> _executeAgentTurn({
    required String convId,
    required String? userMessageId,
    required String text,
    required List<AskChatMessage> history,
    required String locale,
  }) async {
    final storage = ref.read(askStorageRepositoryProvider);
    final requestId = ++_activeRequestId;
    state = state.copyWith(
      isSending: true,
      progressPhase: AskProgressPhase.thinking,
      clearError: true,
      clearRetry: true,
    );

    try {
      final result = await ref
          .read(askAgentUseCaseProvider)
          .execute(
            userMessage: text,
            executor: createAskToolExecutor(ref),
            history: history,
            locale: locale,
            enableWebSearch: state.enableWebSearch,
            onProgress: (phase) {
              if (_activeRequestId != requestId) return;
              state = state.copyWith(progressPhase: phase);
            },
            isCancelled: () => _activeRequestId != requestId,
          );

      if (_activeRequestId != requestId) return;

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
          clearProgress: true,
          errorKind: AskUiErrorKind.failed,
          retryPrompt: text,
          retryMessageId: userMessageId,
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

      if (_activeRequestId != requestId) return;
      state = state.copyWith(
        isSending: false,
        clearProgress: true,
        clearError: true,
        clearRetry: true,
      );
    } on AskCancelledException {
      if (_activeRequestId == requestId) {
        state = state.copyWith(isSending: false, clearProgress: true);
      }
    } on AskQuotaExceededException {
      if (_activeRequestId != requestId) return;
      state = state.copyWith(
        isSending: false,
        clearProgress: true,
        errorKind: AskUiErrorKind.quotaExceeded,
        retryPrompt: text,
        retryMessageId: userMessageId,
      );
    } on AskNotConfiguredException {
      if (_activeRequestId != requestId) return;
      state = state.copyWith(
        isSending: false,
        clearProgress: true,
        errorKind: AskUiErrorKind.notConfigured,
        retryPrompt: text,
        retryMessageId: userMessageId,
      );
    } catch (e) {
      debugPrint('Sonora Ask chat turn failed: $e');
      if (_activeRequestId != requestId) return;
      state = state.copyWith(
        isSending: false,
        clearProgress: true,
        errorKind: AskUiErrorKind.failed,
        retryPrompt: text,
        retryMessageId: userMessageId,
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
