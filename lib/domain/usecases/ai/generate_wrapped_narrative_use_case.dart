import 'dart:convert';
import 'dart:developer' as developer;

import '../../models/wrapped_narrative.dart';
import '../../repositories/llm_completion_repository.dart';
import 'wrapped_narrative_parser.dart';

/// Single English system prompt; [language] selects output language (BCP-47).
String wrappedNarrativeSystemInstruction(String language) {
  final lang = language.trim().isEmpty ? 'en' : language.trim().toLowerCase();
  return '''
You are the Sonora Wrapped narrator. Reply with ONE JSON object and these keys only:
title, hook, artistLine, songLine, closing

Write every string value in language code "$lang".

Rules:
- Real sentences only. Never use ellipsis or "..." as a field value.
- title: max 8 words, emotional; no numbers and no word for minutes.
- hook: 1 sentence under total listening time.
- artistLine: 1 sentence about the top artist, or "" if topArtist is missing.
- songLine: 1 sentence about the top song, or "" if topSong is missing.
- closing: 1–2 closing sentences.
- Mention ONLY artist/song names present in the facts. Do not invent names.
- No markdown, IDs, or URLs.
''';
}

String wrappedNarrativeUserMessage(WrappedFacts facts) {
  final names = facts.allowListedNames.toList()..sort();
  final namesLine =
      names.isEmpty
          ? 'Allowed names: (none — do not invent artists)'
          : 'Allowed names: ${names.join(', ')}';
  return 'Facts JSON:\n$namesLine\n${jsonEncode(facts.toPromptMap())}';
}

bool isPlaceholderField(String value) {
  final t = value.trim();
  if (t.isEmpty) return false;
  return RegExp(r'^[.\u2026]{1,8}$').hasMatch(t);
}

bool isMinutesTitle(String title) {
  final t = title.toLowerCase();
  return RegExp(r'\d').hasMatch(t) &&
      (t.contains('minut') || t.contains('minute'));
}

/// Returns a reject reason, or null if the pack is acceptable.
String? wrappedNarrativeRejectReason(
  WrappedNarrative narrative,
  WrappedFacts facts,
) {
  final title = narrative.title.trim();
  final hook = narrative.hook.trim();
  final closing = narrative.closing.trim();
  if (title.isEmpty || hook.isEmpty || closing.isEmpty) {
    return 'missing_required';
  }
  if (isPlaceholderField(title) ||
      isPlaceholderField(hook) ||
      isPlaceholderField(closing) ||
      (narrative.artistLine != null &&
          isPlaceholderField(narrative.artistLine!)) ||
      (narrative.songLine != null && isPlaceholderField(narrative.songLine!))) {
    return 'placeholder_dots';
  }
  if (isMinutesTitle(title)) return 'title_is_minutes';

  if (facts.topArtistName != null &&
      facts.topArtistName!.trim().isNotEmpty &&
      (narrative.artistLine == null || narrative.artistLine!.trim().isEmpty)) {
    return 'missing_artist_line';
  }
  if (facts.topSongTitle != null &&
      facts.topSongTitle!.trim().isNotEmpty &&
      (narrative.songLine == null || narrative.songLine!.trim().isEmpty)) {
    return 'missing_song_line';
  }

  final allowed = facts.allowListedNames.map((n) => n.toLowerCase()).toSet();
  for (final name in _blockedInventedNames) {
    final blob =
        '${narrative.title} ${narrative.hook} ${narrative.artistLine ?? ''} '
                '${narrative.songLine ?? ''} ${narrative.closing}'
            .toLowerCase();
    if (blob.contains(name) && !allowed.contains(name)) {
      return 'invented_artist';
    }
  }
  return null;
}

const _blockedInventedNames = {'ligabue'};

/// Cloud Wrapped narrator pack from [WrappedFacts].
class GenerateWrappedNarrativeUseCase {
  GenerateWrappedNarrativeUseCase(
    this._llm, {
    WrappedNarrativeParser parser = const WrappedNarrativeParser(),
  }) : _parser = parser;

  final LlmCompletionRepository _llm;
  final WrappedNarrativeParser _parser;

  Future<WrappedNarrative?> execute(WrappedFacts facts) async {
    if (!await _llm.isReady()) {
      developer.log(
        'Wrapped narrative: LLM not ready',
        name: 'WrappedNarrative',
      );
      return null;
    }

    try {
      final raw = await _llm.complete(
        systemInstruction: wrappedNarrativeSystemInstruction(facts.locale),
        userMessage: wrappedNarrativeUserMessage(facts),
        maxOutputTokens: 384,
      );
      final preview = raw.length > 280 ? '${raw.substring(0, 280)}…' : raw;
      final parsed = _parser.parse(raw);
      if (parsed == null) {
        developer.log(
          'Wrapped narrative parse failed. raw=$preview',
          name: 'WrappedNarrative',
        );
        return null;
      }
      final reject = wrappedNarrativeRejectReason(parsed, facts);
      if (reject != null) {
        developer.log(
          'Wrapped narrative rejected ($reject). title=${parsed.title}',
          name: 'WrappedNarrative',
        );
        return null;
      }
      developer.log(
        'Wrapped narrative OK: ${parsed.title}',
        name: 'WrappedNarrative',
      );
      return parsed;
    } catch (e, st) {
      developer.log(
        'Wrapped narrative complete failed: $e',
        name: 'WrappedNarrative',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
