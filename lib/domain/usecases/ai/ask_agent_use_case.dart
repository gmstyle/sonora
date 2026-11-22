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
- Widget-first presentation: whenever you suggest artists, tracks, albums, playlists, podcasts, or episodes, ALWAYS call present_catalog_items (or propose_mix / propose_playlist_write for mixes and playlist edits) using ONLY verified IDs returned by tools in this turn so interactive native cards appear in chat.
- Concise replies with cards: when you attach a mix, playlist proposal, or catalog card, keep your text brief (2-4 short sentences about vibe/highlights) — NEVER dump full 20-50 track lists in plain text, and NEVER ask "Should I proceed?" before creating a Safe Write proposal (the card itself is the user's confirmation).
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
    void Function(AskProgressPhase phase)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return const AskAgentResult(assistantText: '');
    }

    void checkCancelled() {
      if (isCancelled?.call() == true) {
        throw const AskCancelledException();
      }
    }

    void reportPhase(AskProgressPhase phase) {
      if (isCancelled?.call() == true) return;
      onProgress?.call(phase);
    }

    checkCancelled();
    reportPhase(AskProgressPhase.thinking);

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

    final chatMaxTokens = enableWebSearch ? 4096 : 2048;
    LlmChatResponse response = const LlmChatResponse();

    for (var round = 0; round < kAskMaxToolRounds; round++) {
      checkCancelled();
      response = await _chatRepository.completeChat(
        action: AskActionKind.chat,
        messages: wireMessages,
        systemInstruction: systemInstruction,
        locale: locale,
        tools: executor.definitions,
        enableWebSearch: enableWebSearch,
        maxOutputTokens: chatMaxTokens,
        turnId: turnId,
      );
      checkCancelled();
      if (response.quota != null) latestQuota = response.quota;
      collectSources(response.sources);

      if (response.toolCalls.isEmpty) {
        if (executor.attachments.isEmpty &&
            executor.seenTracks.length >= 4 &&
            _looksLikePlaylistOrMixRequest(trimmed)) {
          if (response.content.trim().isNotEmpty) {
            wireMessages.add(
              LlmChatMessage(
                role: 'assistant',
                content: response.content.trim(),
                serverToolCalls: response.serverToolCalls,
                reasoningContent: response.reasoningContent,
              ),
            );
          }
          wireMessages.add(
            const LlmChatMessage(
              role: 'user',
              content: 'Attach the interactive card now using propose_mix or propose_playlist_write with the verified videoIds from the tool results above, then reply in 2-3 short sentences.',
            ),
          );
          final proposalResponse = await _runProposalOnlyWrapUp(
            wireMessages: wireMessages,
            executor: executor,
            systemInstruction: systemInstruction,
            locale: locale,
            enableWebSearch: enableWebSearch,
            maxOutputTokens: chatMaxTokens,
            turnId: turnId,
            usedTools: usedTools,
            collectSources: collectSources,
            onQuota: (q) {
              if (q != null) latestQuota = q;
            },
            checkCancelled: checkCancelled,
            reportPhase: reportPhase,
          );
          final reply = proposalResponse.content.trim().isNotEmpty
              ? proposalResponse.content.trim()
              : (executor.attachments.isEmpty ? response.content.trim() : '');
          return _finalizeResult(
            reply,
            executor: executor,
            usedTools: usedTools,
            sources: sources,
            quota: latestQuota,
          );
        }
        return _finalizeResult(
          response.content.trim(),
          executor: executor,
          usedTools: usedTools,
          sources: sources,
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
          reasoningContent: response.reasoningContent,
        ),
      );

      final toolResults = await _executeBatch(
        batch: batch,
        executor: executor,
        usedTools: usedTools,
        checkCancelled: checkCancelled,
        reportPhase: reportPhase,
      );
      for (final res in toolResults) {
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

    checkCancelled();

    // If rounds ended without any rich card yet, give the model one focused
    // proposal-only turn using presentation tools before closing with text.
    final LlmChatResponse finalResponse;
    if (executor.attachments.isEmpty && executor.hasSeenCatalogEntities) {
      finalResponse = await _runProposalOnlyWrapUp(
        wireMessages: wireMessages,
        executor: executor,
        systemInstruction: systemInstruction,
        locale: locale,
        enableWebSearch: enableWebSearch,
        maxOutputTokens: chatMaxTokens,
        turnId: turnId,
        usedTools: usedTools,
        collectSources: collectSources,
        onQuota: (q) {
          if (q != null) latestQuota = q;
        },
        checkCancelled: checkCancelled,
        reportPhase: reportPhase,
      );
    } else {
      reportPhase(AskProgressPhase.finalizing);
      finalResponse = await _chatRepository.completeChat(
        action: AskActionKind.chat,
        messages: wireMessages,
        systemInstruction: systemInstruction,
        locale: locale,
        tools: executor.definitions,
        toolChoice: 'none',
        enableWebSearch: enableWebSearch,
        maxOutputTokens: chatMaxTokens,
        turnId: turnId,
      );
      checkCancelled();
      if (finalResponse.quota != null) latestQuota = finalResponse.quota;
      collectSources(finalResponse.sources);
    }

    return _finalizeResult(
      finalResponse.content.trim(),
      executor: executor,
      usedTools: usedTools,
      sources: sources,
      quota: latestQuota,
    );
  }

  Future<List<AskToolResult>> _executeBatch({
    required List<AskToolCall> batch,
    required AskToolExecutor executor,
    required List<String> usedTools,
    required void Function() checkCancelled,
    required void Function(AskProgressPhase phase) reportPhase,
  }) async {
    checkCancelled();
    final results = List<AskToolResult?>.filled(batch.length, null);
    final readIndices = <int>[];
    final presentationIndices = <int>[];

    for (var i = 0; i < batch.length; i++) {
      usedTools.add(batch[i].name);
      if (AskToolExecutor.isPresentationTool(batch[i].name)) {
        presentationIndices.add(i);
      } else {
        readIndices.add(i);
      }
    }

    if (readIndices.isNotEmpty) {
      reportPhase(_phaseForReadTools(batch, readIndices));
      var cursor = 0;
      Future<void> worker() async {
        while (true) {
          checkCancelled();
          if (cursor >= readIndices.length) return;
          final batchIdx = readIndices[cursor++];
          results[batchIdx] = await executor.execute(batch[batchIdx]);
        }
      }

      final concurrency = min(4, readIndices.length);
      await Future.wait([for (var w = 0; w < concurrency; w++) worker()]);
      checkCancelled();
    }

    if (presentationIndices.isNotEmpty) {
      checkCancelled();
      reportPhase(AskProgressPhase.buildingProposal);
      for (final batchIdx in presentationIndices) {
        checkCancelled();
        results[batchIdx] = await executor.execute(batch[batchIdx]);
      }
      checkCancelled();
    }

    return [for (final r in results) r!];
  }

  AskProgressPhase _phaseForReadTools(
    List<AskToolCall> batch,
    List<int> readIndices,
  ) {
    final names = {for (final i in readIndices) batch[i].name};
    if (names.contains('get_local_playlist_tracks')) {
      return AskProgressPhase.readingPlaylist;
    }
    if (names.contains('get_song_related') ||
        names.contains('get_artist_info')) {
      return AskProgressPhase.exploringSimilar;
    }
    if (names.contains('search_catalog') ||
        names.contains('get_album_or_playlist') ||
        names.contains('get_charts_or_moods') ||
        names.contains('get_song_lyrics')) {
      return AskProgressPhase.searchingCatalog;
    }
    if (names.contains('get_taste_profile') ||
        names.contains('get_listening_history') ||
        names.contains('search_local_library') ||
        names.contains('get_now_playing')) {
      return AskProgressPhase.readingProfile;
    }
    return AskProgressPhase.thinking;
  }

  Future<LlmChatResponse> _runProposalOnlyWrapUp({
    required List<LlmChatMessage> wireMessages,
    required AskToolExecutor executor,
    required String systemInstruction,
    required String locale,
    required bool enableWebSearch,
    required int maxOutputTokens,
    required String turnId,
    required List<String> usedTools,
    required void Function(List<GroundedSource>) collectSources,
    required void Function(AskQuotaInfo?) onQuota,
    required void Function() checkCancelled,
    required void Function(AskProgressPhase phase) reportPhase,
  }) async {
    checkCancelled();
    reportPhase(AskProgressPhase.buildingProposal);
    final proposalTools = executor.presentationDefinitions;
    final proposalResponse = await _chatRepository.completeChat(
      action: AskActionKind.chat,
      messages: wireMessages,
      systemInstruction: systemInstruction,
      locale: locale,
      tools: proposalTools,
      toolChoice: 'auto',
      enableWebSearch: enableWebSearch,
      maxOutputTokens: maxOutputTokens,
      turnId: turnId,
    );
    checkCancelled();
    onQuota(proposalResponse.quota);
    collectSources(proposalResponse.sources);

    if (proposalResponse.toolCalls.isEmpty) {
      return proposalResponse;
    }

    final batch = proposalResponse.toolCalls.length > kAskMaxToolCallsPerRound
        ? proposalResponse.toolCalls.sublist(0, kAskMaxToolCallsPerRound)
        : proposalResponse.toolCalls;

    wireMessages.add(
      LlmChatMessage(
        role: 'assistant',
        content: proposalResponse.content.isEmpty
            ? null
            : proposalResponse.content,
        toolCalls: batch,
        serverToolCalls: proposalResponse.serverToolCalls,
        reasoningContent: proposalResponse.reasoningContent,
      ),
    );
    final toolResults = await _executeBatch(
      batch: batch,
      executor: executor,
      usedTools: usedTools,
      checkCancelled: checkCancelled,
      reportPhase: reportPhase,
    );
    for (final res in toolResults) {
      wireMessages.add(
        LlmChatMessage(
          role: 'tool',
          toolCallId: res.toolCallId,
          name: res.name,
          content: res.contentJson,
        ),
      );
    }

    checkCancelled();
    reportPhase(AskProgressPhase.finalizing);
    final summaryResponse = await _chatRepository.completeChat(
      action: AskActionKind.chat,
      messages: wireMessages,
      systemInstruction: systemInstruction,
      locale: locale,
      tools: proposalTools,
      toolChoice: 'none',
      enableWebSearch: enableWebSearch,
      maxOutputTokens: maxOutputTokens,
      turnId: turnId,
    );
    checkCancelled();
    onQuota(summaryResponse.quota);
    collectSources(summaryResponse.sources);
    return summaryResponse;
  }

  AskAgentResult _finalizeResult(
    String assistantText, {
    required AskToolExecutor executor,
    required List<String> usedTools,
    required List<GroundedSource> sources,
    required AskQuotaInfo? quota,
  }) {
    _autoAttachMentionedEntities(assistantText, executor);
    if (assistantText.isEmpty && executor.attachments.isEmpty) {
      throw const AskEmptyResponseException();
    }
    return AskAgentResult(
      assistantText: assistantText,
      attachments: List.unmodifiable(executor.attachments),
      toolNamesUsed: usedTools.toSet().toList(growable: false),
      sources: List.unmodifiable(sources),
      quota: quota,
    );
  }
}

bool _looksLikePlaylistOrMixRequest(String text) {
  final lower = text.toLowerCase();
  const cues = [
    'playlist',
    'mix',
    'scaletta',
    'espandi',
    'expand',
    'brani',
    'tracks',
    'songs',
    'aggiungi',
    'append',
    'porta a',
    'crea',
    'draft',
    'build',
  ];
  return cues.any(lower.contains);
}

void _autoAttachMentionedEntities(
  String assistantText,
  AskToolExecutor executor,
) {
  if (assistantText.isEmpty) return;
  final lowerText = assistantText.toLowerCase();

  bool has<T extends AskAttachment>() =>
      executor.attachments.any((a) => a is T);

  List<T> matchMentioned<T>(Iterable<T> candidates, String Function(T) nameOf) {
    final hits = <(int, T)>[];
    for (final item in candidates) {
      final idx = _findMatchIndex(lowerText, nameOf(item));
      if (idx >= 0) hits.add((idx, item));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final h in hits.take(8)) h.$2];
  }

  if (!has<AskArtistsAttachment>() && executor.seenArtists.isNotEmpty) {
    final matched = matchMentioned(executor.seenArtists.values, (a) => a.name);
    if (matched.isNotEmpty) {
      executor.attachments.add(
        AskArtistsAttachment(title: '', artists: matched),
      );
    }
  }

  if (!has<AskAlbumsAttachment>() && executor.seenAlbums.isNotEmpty) {
    final matched = matchMentioned(executor.seenAlbums.values, (a) => a.name);
    if (matched.isNotEmpty) {
      executor.attachments.add(AskAlbumsAttachment(title: '', albums: matched));
    }
  }

  final hasPlaylistSurface =
      has<AskPlaylistsAttachment>() ||
      has<AskMixAttachment>() ||
      has<AskPlaylistWriteProposal>();
  if (!hasPlaylistSurface &&
      (executor.seenPlaylists.isNotEmpty ||
          executor.seenLocalPlaylists.isNotEmpty)) {
    final allPlaylists = <AskPlaylistRef>[
      ...executor.seenLocalPlaylists.values,
      ...executor.seenPlaylists.values,
    ];
    final matched = matchMentioned(allPlaylists, (p) => p.name);
    if (matched.isNotEmpty) {
      executor.attachments.add(
        AskPlaylistsAttachment(title: '', playlists: matched),
      );
    }
  }

  if (!has<AskPodcastsAttachment>() && executor.seenPodcasts.isNotEmpty) {
    final matched = matchMentioned(executor.seenPodcasts.values, (p) => p.name);
    if (matched.isNotEmpty) {
      executor.attachments.add(
        AskPodcastsAttachment(title: '', podcasts: matched),
      );
    }
  }

  if (!has<AskEpisodesAttachment>() && executor.seenEpisodes.isNotEmpty) {
    final matched = matchMentioned(executor.seenEpisodes.values, (e) => e.name);
    if (matched.isNotEmpty) {
      executor.attachments.add(
        AskEpisodesAttachment(title: '', episodes: matched),
      );
    }
  }

  final hasTrackSurface =
      has<AskTracksAttachment>() ||
      has<AskMixAttachment>() ||
      has<AskPlaylistWriteProposal>();
  if (!hasTrackSurface && executor.seenTracks.isNotEmpty) {
    final matched = matchMentioned(executor.seenTracks.values, (t) => t.title);
    if (matched.isNotEmpty) {
      executor.attachments.add(AskTracksAttachment(title: '', tracks: matched));
    }
  }
}

int _findMatchIndex(String lowerText, String rawName) {
  final needle = rawName.trim().toLowerCase();
  if (needle.length < 2) return -1;
  var start = 0;
  while (true) {
    final idx = lowerText.indexOf(needle, start);
    if (idx < 0) return -1;
    if (needle.length > 3) return idx;
    final leftOk = idx == 0 || !_isAsciiAlnum(lowerText.codeUnitAt(idx - 1));
    final rightIdx = idx + needle.length;
    final rightOk =
        rightIdx >= lowerText.length ||
        !_isAsciiAlnum(lowerText.codeUnitAt(rightIdx));
    if (leftOk && rightOk) return idx;
    start = idx + 1;
  }
}

bool _isAsciiAlnum(int unit) =>
    (unit >= 48 && unit <= 57) ||
    (unit >= 65 && unit <= 90) ||
    (unit >= 97 && unit <= 122);

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
      case final AskTracksAttachment tracks:
        parts.add('[Tracks "${tracks.title}": ${tracks.tracks.length}]');
      case final AskArtistsAttachment artists:
        parts.add('[Artists "${artists.title}": ${artists.artists.length}]');
      case final AskAlbumsAttachment albums:
        parts.add('[Albums "${albums.title}": ${albums.albums.length}]');
      case final AskPlaylistsAttachment playlists:
        parts.add(
          '[Playlists "${playlists.title}": ${playlists.playlists.length}]',
        );
      case final AskPodcastsAttachment podcasts:
        parts.add(
          '[Podcasts "${podcasts.title}": ${podcasts.podcasts.length}]',
        );
      case final AskEpisodesAttachment episodes:
        parts.add(
          '[Episodes "${episodes.title}": ${episodes.episodes.length}]',
        );
      case final AskInsightsAttachment insights:
        parts.add('[Insights "${insights.title}"]');
    }
  }
  return parts.join(' ');
}
