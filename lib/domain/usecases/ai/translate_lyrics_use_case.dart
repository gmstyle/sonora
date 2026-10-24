import 'dart:convert';

import '../../repositories/llm_completion_repository.dart';

/// Max lyrics characters sent to the model (token budget).
const kTranslateLyricsMaxChars = 4000;

const kAskTranslateLyricsSystemInstruction = r'''
You translate song lyrics into the requested language.
Reply with ONLY a single JSON object, no markdown, no commentary.
Schema:
{
  "translation": "string — full translation of the provided lyrics"
}
Rules:
- Translate meaning faithfully; keep line breaks when practical.
- Do not add commentary, titles, or explanations outside the JSON.
- If lyrics are empty, return {"translation":""}.
''';

/// Cloud Ask: translate already-fetched lyrics into [targetLanguage].
class TranslateLyricsUseCase {
  TranslateLyricsUseCase(this._llm);

  final LlmCompletionRepository _llm;

  Future<String?> execute({
    required String lyrics,
    required String targetLanguage,
  }) async {
    final trimmed = lyrics.trim();
    if (trimmed.isEmpty) return null;
    if (!await _llm.isReady()) return null;

    final clipped =
        trimmed.length > kTranslateLyricsMaxChars
            ? trimmed.substring(0, kTranslateLyricsMaxChars)
            : trimmed;

    try {
      final raw = await _llm.complete(
        systemInstruction: kAskTranslateLyricsSystemInstruction,
        userMessage: 'Target language: $targetLanguage\n\nLyrics:\n$clipped',
        maxOutputTokens: 2048,
      );
      return _parseTranslation(raw);
    } catch (_) {
      return null;
    }
  }

  String? _parseTranslation(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    final fence = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fence != null) {
      text = fence.group(1)!.trim();
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is! Map) return null;
      final t = decoded['translation']?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }
}
