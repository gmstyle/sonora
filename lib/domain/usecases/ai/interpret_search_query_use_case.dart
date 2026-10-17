import '../../models/music_search_intent.dart';
import '../../repositories/on_device_llm_repository.dart';
import 'music_search_intent_parser.dart';

/// System prompt for Ask search. Output must be JSON only; no catalog IDs.
const kAskSearchSystemInstruction = '''
You convert natural-language music requests into a JSON object for YouTube Music search.
Reply with ONLY a single JSON object, no markdown, no commentary.
Schema:
{
  "searchQuery": "string — concise English keywords for catalog search",
  "mood": "string or null",
  "genres": ["string"],
  "era": "string or null (e.g. 1990s)",
  "seedArtists": ["string"],
  "contentType": "any|songs|artists|albums|playlists|podcasts|episodes"
}
Rules:
- Never invent video IDs, URLs, or playlist IDs.
- searchQuery must be non-empty and useful for keyword search.
- Keep genres/artists in the language they are commonly catalogued (often English or original names).
- If the user asks in Italian or another language, still fill the JSON; searchQuery may mix terms.
''';

class InterpretSearchQueryUseCase {
  InterpretSearchQueryUseCase(
    this._llm, {
    MusicSearchIntentParser parser = const MusicSearchIntentParser(),
  }) : _parser = parser;

  final OnDeviceLlmRepository _llm;
  final MusicSearchIntentParser _parser;

  /// Returns a structured intent, or null when the model is unavailable /
  /// output cannot be parsed (caller falls back to keyword search).
  Future<MusicSearchIntent?> execute(String userQuery) async {
    final trimmed = userQuery.trim();
    if (trimmed.isEmpty) return null;
    if (!await _llm.isModelReady()) return null;

    try {
      final raw = await _llm.complete(
        systemInstruction: kAskSearchSystemInstruction,
        userMessage: trimmed,
        maxOutputTokens: 256,
      );
      return _parser.parse(raw);
    } catch (_) {
      return null;
    }
  }
}
