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
    this.pendingPrompt,
    this.pendingUserMessageId,
    this.pendingConversationId,
  });

  final String? activeConversationId;
  final bool isSending;
  final bool enableWebSearch;
  final AskUiErrorKind? errorKind;
  final AskProgressPhase? progressPhase;
  final String? retryPrompt;
  final String? retryMessageId;

  /// Prompt of the in-flight turn, restored in the composer when stopped.
  final String? pendingPrompt;

  /// User message persisted by the in-flight turn, removed when stopped.
  final String? pendingUserMessageId;

  /// Conversation the in-flight turn belongs to.
  final String? pendingConversationId;

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
    String? pendingPrompt,
    String? pendingUserMessageId,
    String? pendingConversationId,
    bool clearPending = false,
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
      pendingPrompt: clearPending
          ? null
          : (pendingPrompt ?? this.pendingPrompt),
      pendingUserMessageId: clearPending
          ? null
          : (pendingUserMessageId ?? this.pendingUserMessageId),
      pendingConversationId: clearPending
          ? null
          : (pendingConversationId ?? this.pendingConversationId),
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
      clearPending: true,
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
      clearPending: true,
    );
  }

  void toggleWebSearch() {
    state = state.copyWith(enableWebSearch: !state.enableWebSearch);
  }

  /// Stops the in-flight turn, drops the user message it persisted and returns
  /// the prompt to restore in the composer. A conversation created by the
  /// stopped turn is removed too, so it never leaves an empty chat in history.
  Future<String?> cancelActiveRequest() async {
    if (!state.isSending) return null;
    final prompt = state.pendingPrompt;
    final userMessageId = state.pendingUserMessageId;
    final conversationId = state.pendingConversationId;
    _activeRequestId++;
    state = state.copyWith(
      isSending: false,
      clearProgress: true,
      clearError: true,
      clearRetry: true,
      clearPending: true,
    );

    final storage = ref.read(askStorageRepositoryProvider);
    try {
      if (userMessageId != null) {
        await storage.deleteMessage(userMessageId);
      }
      if (conversationId != null) {
        final remaining = await storage.getMessages(conversationId);
        if (remaining.isEmpty) {
          await storage.deleteConversation(conversationId);
          if (state.activeConversationId == conversationId) {
            state = state.copyWith(clearConversation: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Sonora Ask cancelled turn cleanup failed: $e');
    }
    return prompt;
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
        clearPending: true,
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
      clearPending: true,
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
      pendingUserMessageId: userMsgId,
      pendingPrompt: text,
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
      pendingUserMessageId: retryMsgId,
      pendingPrompt: prompt,
    );
  }

  /// Replaces the last assistant answer (or a trailing user message left by a
  /// stopped regeneration) with a fresh turn using the same prompt.
  Future<void> regenerateLastReply({required String locale}) async {
    final convId = state.activeConversationId;
    if (convId == null || state.isSending) return;
    if (!await _ensurePreflightReady()) return;

    final storage = ref.read(askStorageRepositoryProvider);
    final messages = await storage.getMessages(convId);
    if (messages.isEmpty) return;

    final last = messages.last;
    final String prompt;
    final String? userMessageId;
    final List<AskChatMessage> history;
    if (last.isUser) {
      prompt = last.content.trim();
      userMessageId = last.id;
      history = messages.where((m) => m.id != last.id).toList(growable: false);
    } else {
      if (messages.length < 2 || !messages[messages.length - 2].isUser) return;
      final userMessage = messages[messages.length - 2];
      prompt = userMessage.content.trim();
      userMessageId = userMessage.id;
      history = messages
          .where((m) => m.id != userMessage.id && m.id != last.id)
          .toList(growable: false);
      await storage.deleteMessage(last.id);
    }
    if (prompt.isEmpty) return;

    await _executeAgentTurn(
      convId: convId,
      userMessageId: userMessageId,
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
    String? pendingUserMessageId,
    String? pendingPrompt,
  }) async {
    final storage = ref.read(askStorageRepositoryProvider);
    final requestId = ++_activeRequestId;
    state = state.copyWith(
      isSending: true,
      progressPhase: AskProgressPhase.thinking,
      clearError: true,
      clearRetry: true,
      clearPending: true,
    );
    if (pendingUserMessageId != null || pendingPrompt != null) {
      state = state.copyWith(
        pendingUserMessageId: pendingUserMessageId,
        pendingPrompt: pendingPrompt,
        pendingConversationId: convId,
      );
    }

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
          clearPending: true,
          errorKind: AskUiErrorKind.failed,
          retryPrompt: text,
          retryMessageId: userMessageId,
        );
        return;
      }

      final assistantTime = DateTime.now();
      final assistantMessageId = _newId('msg');
      await storage.insertMessage(
        AskChatMessage(
          id: assistantMessageId,
          conversationId: convId,
          role: 'assistant',
          content: result.assistantText,
          attachments: attachments,
          toolNamesUsed: result.toolNamesUsed,
          createdAt: assistantTime,
        ),
      );

      // The turn was stopped while the reply was being written: drop it so a
      // cancelled turn can never leave an orphan assistant message behind.
      if (_activeRequestId != requestId) {
        await storage.deleteMessage(assistantMessageId);
        return;
      }

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
        clearPending: true,
      );
    } on AskCancelledException {
      if (_activeRequestId == requestId) {
        state = state.copyWith(
          isSending: false,
          clearProgress: true,
          clearPending: true,
        );
      }
    } on AskQuotaExceededException {
      if (_activeRequestId != requestId) return;
      state = state.copyWith(
        isSending: false,
        clearProgress: true,
        clearPending: true,
        errorKind: AskUiErrorKind.quotaExceeded,
        retryPrompt: text,
        retryMessageId: userMessageId,
      );
    } on AskNotConfiguredException {
      if (_activeRequestId != requestId) return;
      state = state.copyWith(
        isSending: false,
        clearProgress: true,
        clearPending: true,
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
        clearPending: true,
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

  Future<void> removeTrackFromAttachment({
    required AskChatMessage message,
    required int attachmentIndex,
    required String videoId,
  }) async {
    if (attachmentIndex < 0 || attachmentIndex >= message.attachments.length) {
      return;
    }
    final target = message.attachments[attachmentIndex];
    final updated = List<AskAttachment>.from(message.attachments);
    if (target is AskMixAttachment && target.savedPlaylistId == null) {
      final remaining = target.tracks
          .where((t) => t.videoId != videoId)
          .toList(growable: false);
      if (remaining.length == target.tracks.length || remaining.isEmpty) {
        return;
      }
      updated[attachmentIndex] = target.copyWith(tracks: remaining);
    } else if (target is AskPlaylistWriteProposal && target.isPending) {
      final remaining = target.tracks
          .where((t) => t.videoId != videoId)
          .toList(growable: false);
      if (remaining.length == target.tracks.length || remaining.isEmpty) {
        return;
      }
      updated[attachmentIndex] = target.copyWith(tracks: remaining);
    } else {
      return;
    }
    await ref
        .read(askStorageRepositoryProvider)
        .updateMessageAttachments(message.id, updated);
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
