import 'dart:math';

import '../../../core/constants/ai_constants.dart';
import '../../models/ask_chat_models.dart';
import '../../models/grounded_llm_result.dart';
import '../../repositories/llm_chat_repository.dart';
import 'ask_tool_executor.dart';
import 'dsml_parser.dart';

/// System prompt used when running in BYOK mode (managed proxy overrides it
/// with its authoritative server-side copy).
String buildAskChatSystemInstruction(String locale) {
  final lang = locale.trim().isEmpty ? 'en' : locale.trim();
  return '''
You are Sonora Ask, the friendly music companion built into the Sonora app.
Reply in language "$lang" unless the user explicitly writes in another language.

Persona & Tone:
- Talk like a passionate, laid-back friend sharing music recs: informal, warm, conversational, never stiff, robotic, or corporate.
- When replying in Italian, always use informal "tu" (never formal "Lei" or "Voi").
- Use light, clean Markdown when helpful (short bold highlights, clean bullet points, short paragraphs — never walls of text).
- Strictly keep your identity as Sonora Ask: NEVER mention DeepSeek, OpenAI, LLMs, AI models, providers, APIs, internal tool names, or JSON schemas. If asked who or what you are or what model powers you, simply say you are Sonora Ask, Sonora's music companion.

Scope & Guardrails:
- ONLY help with music, podcasts, playlists, listening history, artists, albums, lyrics, and audio discovery inside Sonora.
- If the user asks about anything unrelated to music or audio (coding, math, recipes, general trivia, etc.), steer back lightly in 1-2 short sentences without calling any tools.
- Never invent videoId, artistId, albumId, playlistId, or URLs. Always obtain real IDs by calling the provided tools first.
- When building a mix or playlist suggestion, inspect real tracks with tools first and then call propose_mix or propose_playlist_write using ONLY verified videoIds returned by tools in this turn.
- For larger mixes or playlist expansions (20-60 tracks), batch at most 4-6 high-yield tool calls per round (prefer get_song_related with limit 25-30 on 2-3 seed tracks, get_album_or_playlist, or broad search_catalog queries with limit 15-20 instead of searching songs one by one) and call propose_mix or propose_playlist_write as soon as you have enough verified tracks.
- Safe Write rule: never assume a playlist or mix is saved automatically; always present proposals so the user confirms saving.
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

    final wireMessages = <LlmChatMessage>[];
    for (final m in recent) {
      if (m.isError) continue;
      if (m.role != 'user' && m.role != 'assistant') continue;
      final cleaned = m.role == 'assistant'
          ? parseAndStripDsml(m.content).cleanContent.trim()
          : m.content.trim();
      final attachmentSummary =
          m.role == 'assistant' && m.attachments.isNotEmpty
          ? _summarizeAttachments(m.attachments)
          : '';
      final effectiveContent = [
        if (cleaned.isNotEmpty) cleaned,
        if (attachmentSummary.isNotEmpty) attachmentSummary,
      ].join('\n');
      if (effectiveContent.trim().isEmpty) continue;
      wireMessages.add(LlmChatMessage(role: m.role, content: effectiveContent));
    }
    wireMessages.add(LlmChatMessage(role: 'user', content: trimmed));

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
        maxOutputTokens: 2048,
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

      final batch = response.toolCalls.length > kAskMaxToolCallsPerRound
          ? response.toolCalls.sublist(0, kAskMaxToolCallsPerRound)
          : response.toolCalls;

      wireMessages.add(
        LlmChatMessage(
          role: 'assistant',
          content: response.content.isEmpty ? null : response.content,
          toolCalls: batch,
          serverToolCalls: response.serverToolCalls,
        ),
      );

      for (final call in batch) {
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

    // Final tool-free wrap-up round sharing the same turnId (keep tools in the
    // request with toolChoice='none' so the model formats a plain reply instead
    // of emitting raw DSML markup).
    final finalResponse = await _chatRepository.completeChat(
      action: AskActionKind.chat,
      messages: wireMessages,
      systemInstruction: systemInstruction,
      locale: locale,
      tools: executor.definitions,
      toolChoice: 'none',
      enableWebSearch: enableWebSearch,
      maxOutputTokens: 2048,
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

String _summarizeAttachments(List<AskAttachment> attachments) {
  final parts = <String>[];
  for (final att in attachments) {
    switch (att) {
      case final AskMixAttachment mix:
        parts.add('[Mix "${mix.title}": ${mix.tracks.length} tracks]');
      case final AskPlaylistWriteProposal prop:
        parts.add(
          '[Playlist ${prop.operation} proposal "${prop.playlistName}": ${prop.tracks.length} tracks (${prop.status})]',
        );
      case final AskArtistsAttachment artists:
        parts.add('[Artists "${artists.title}": ${artists.artists.length}]');
      case final AskInsightsAttachment insights:
        parts.add('[Insights "${insights.title}"]');
    }
  }
  return parts.join(' ');
}
