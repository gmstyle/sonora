import '../../models/music_search_intent.dart';
import '../../repositories/llm_completion_repository.dart';
import 'music_search_intent_parser.dart';

/// System prompt for Ask → Mix for this moment. JSON only; no catalog IDs.
const kAskMixSystemInstruction = '''
You convert a natural-language music mood request into a JSON object for building a playable mix.
Reply with ONLY a single JSON object, no markdown, no commentary.
Schema:
{
  "searchQuery": "string — concise English keywords useful for YouTube Music song search",
  "mood": "calm|energetic|focus|happy|melancholic|romantic|workout|party|chill|null",
  "energy": "low|medium|high|null",
  "genres": ["string"],
  "era": "string or null (e.g. 1990s)",
  "seedArtists": ["string"],
  "source": "history|ytm|both",
  "contentType": "songs"
}
Rules:
- Never invent video IDs, URLs, or playlist IDs.
- searchQuery must be non-empty and useful for keyword search.
- source=history when the user wants their own library / past listening; ytm for catalog discovery; both when unsure or mixed.
- Prefer mood and energy from the closed enums above (English keys).
- Keep genres/artists in the language they are commonly catalogued.
- If the user asks in Italian or another language, still fill the JSON; searchQuery may mix terms.
''';

class InterpretMixQueryUseCase {
  InterpretMixQueryUseCase(
    this._llm, {
    MusicSearchIntentParser parser = const MusicSearchIntentParser(),
  }) : _parser = parser;

  final LlmCompletionRepository _llm;
  final MusicSearchIntentParser _parser;

  /// Returns a structured mix intent, or null when the model is unavailable /
  /// output cannot be parsed.
  Future<MusicSearchIntent?> execute(String userQuery) async {
    final trimmed = userQuery.trim();
    if (trimmed.isEmpty) return null;
    if (!await _llm.isReady()) return null;

    try {
      final raw = await _llm.complete(
        systemInstruction: kAskMixSystemInstruction,
        userMessage: trimmed,
        maxOutputTokens: 256,
      );
      return _parser.parse(raw);
    } catch (_) {
      return null;
    }
  }
}
