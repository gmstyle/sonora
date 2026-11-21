import 'dart:math';

import '../../../core/constants/ai_constants.dart';
import '../../models/ask_chat_models.dart';
import '../../models/grounded_llm_result.dart';
import '../../repositories/llm_chat_repository.dart';
import 'ask_tool_executor.dart';

/// System prompt used when running in BYOK mode (managed proxy overrides it
/// with its authoritative server-side copy).
String buildAskChatSystemInstruction(String locale) {
  final lang = locale.trim().isEmpty ? 'en' : locale.trim();
  return '''
You are Sonora Ask, the built-in music assistant for the Sonora music app.
Reply in language "$lang" unless the user explicitly writes in another language.
Scope & Guardrails:
- ONLY help with music, podcasts, playlists, listening history, artists, albums, lyrics, and audio discovery inside Sonora.
- If the user asks for anything unrelated to music/audio (coding, math, recipes, general trivia, etc.), politely refuse in 1-2 short sentences and invite them to ask a music question instead without calling any tools.
- Never invent videoId, artistId, albumId, playlistId, or URLs. Always obtain real IDs by calling the provided tools first.
- When building a mix or playlist suggestion, inspect real tracks with tools first and then call propose_mix or propose_playlist_write using ONLY verified videoIds returned by tools in this turn.
- Safe Write rule: never assume a playlist or mix is saved automatically; always present proposals so the user confirms saving.
- Keep answers concise, warm, and focused on music.
''';
}

class AskAgentResult {
  const AskAgentResult({
    required this.assistantText,
    this.attachments = const [],
    this.toolNamesUsed = const [],
    this.sources = const [],
    this.quota,
  });

  final String assistantText;
  final List<AskAttachment> attachments;
  final List<String> toolNamesUsed;
  final List<GroundedSource> sources;
  final AskQuotaInfo? quota;
}

/// Runs a multi-round Function Calling conversation turn over [LlmChatRepository]
/// and [AskToolExecutor], sharing one `turnId` across all rounds so the user is
/// charged at most 1 credit per visible turn.
class AskAgentUseCase {
  AskAgentUseCase(this._chatRepository);

  final LlmChatRepository _chatRepository;
  final Random _random = Random();

  Future<AskAgentResult> execute({
    required String userMessage,
    required AskToolExecutor executor,
    List<AskChatMessage> history = const [],
    String locale = 'en',
    bool enableWebSearch = false,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return const AskAgentResult(assistantText: '');
    }

    final turnId =
        'turn_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999999)}';
    final recent = history.length > kAskHistoryWindowMessages
        ? history.sublist(history.length - kAskHistoryWindowMessages)
        : history;

    final wireMessages = <LlmChatMessage>[
      for (final m in recent)
        if (m.role == 'user' || m.role == 'assistant')
          LlmChatMessage(role: m.role, content: m.content),
      LlmChatMessage(role: 'user', content: trimmed),
    ];

    final systemInstruction = buildAskChatSystemInstruction(locale);
    final usedTools = <String>[];
    final sources = <GroundedSource>[];
    final seenUris = <String>{};
    AskQuotaInfo? latestQuota;

    void collectSources(List<GroundedSource> incoming) {
      for (final s in incoming) {
        if (seenUris.add(s.uri)) {
          sources.add(s);
        }
      }
    }

    LlmChatResponse response = const LlmChatResponse();

    for (var round = 0; round < kAskMaxToolRounds; round++) {
      response = await _chatRepository.completeChat(
        action: AskActionKind.chat,
        messages: wireMessages,
        systemInstruction: systemInstruction,
        locale: locale,
        tools: executor.definitions,
        enableWebSearch: enableWebSearch,
        maxOutputTokens: 900,
        turnId: turnId,
      );
      if (response.quota != null) latestQuota = response.quota;
      collectSources(response.sources);

      if (response.toolCalls.isEmpty) {
        return AskAgentResult(
          assistantText: response.content.trim(),
          attachments: List.unmodifiable(executor.attachments),
          toolNamesUsed: usedTools.toSet().toList(growable: false),
          sources: List.unmodifiable(sources),
          quota: latestQuota,
        );
      }

      wireMessages.add(
        LlmChatMessage(
          role: 'assistant',
          content: response.content.isEmpty ? null : response.content,
          toolCalls: response.toolCalls,
          serverToolCalls: response.serverToolCalls,
        ),
      );

      for (final call in response.toolCalls) {
        usedTools.add(call.name);
        final res = await executor.execute(call);
        wireMessages.add(
          LlmChatMessage(
            role: 'tool',
            toolCallId: res.toolCallId,
            name: res.name,
            content: res.contentJson,
          ),
        );
      }
    }

    // Final tool-free wrap-up round sharing the same turnId.
    final finalResponse = await _chatRepository.completeChat(
      action: AskActionKind.chat,
      messages: wireMessages,
      systemInstruction: systemInstruction,
      locale: locale,
      enableWebSearch: enableWebSearch,
      maxOutputTokens: 900,
      turnId: turnId,
    );
    if (finalResponse.quota != null) latestQuota = finalResponse.quota;
    collectSources(finalResponse.sources);

    return AskAgentResult(
      assistantText: finalResponse.content.trim(),
      attachments: List.unmodifiable(executor.attachments),
      toolNamesUsed: usedTools.toSet().toList(growable: false),
      sources: List.unmodifiable(sources),
      quota: latestQuota,
    );
  }
}
