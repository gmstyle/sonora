import '../../repositories/llm_completion_repository.dart';

/// System prompt for cleaning Spotify metadata into a YTM search string.
const kRewriteSpotifySearchSystemInstruction = '''
You rewrite a Spotify track title and artist into a short YouTube Music search query.
Reply with ONLY the search query string, or a JSON object {"searchQuery":"..."}.
No markdown, no commentary, no video IDs or URLs.
Strip remaster/radio edit/feat noise when helpful. Keep the primary artist name.
Example input: title="Blinding Lights - Remastered 2020" artist="The Weeknd"
Example output: Blinding Lights The Weeknd
''';

/// On-device rewrite of dirty Spotify title/artist into a short search query.
class RewriteSpotifySearchQueryUseCase {
  RewriteSpotifySearchQueryUseCase(this._llm);

  final LlmCompletionRepository _llm;

  /// Returns a cleaned query, or null when the model is unavailable / fails.
  Future<String?> execute({
    required String title,
    required String artist,
  }) async {
    final t = title.trim();
    final a = artist.trim();
    if (t.isEmpty) return null;
    if (!await _llm.isReady()) return null;

    final userMessage = a.isEmpty ? 'title: $t' : 'title: $t\nartist: $a';

    try {
      final raw = await _llm.complete(
        systemInstruction: kRewriteSpotifySearchSystemInstruction,
        userMessage: userMessage,
        maxOutputTokens: 64,
      );
      return parseRewriteOutput(raw);
    } catch (_) {
      return null;
    }
  }

  /// Extracts a search string from plain text or a tiny JSON object.
  static String? parseRewriteOutput(String? raw) {
    if (raw == null) return null;
    var text = raw.trim();
    if (text.isEmpty) return null;

    // Strip markdown fences if the model wraps them anyway.
    if (text.startsWith('```')) {
      text = text.replaceFirst(
        RegExp(r'^```(?:json)?\s*', caseSensitive: false),
        '',
      );
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
      text = text.trim();
    }

    if (text.startsWith('{')) {
      final match = RegExp(r'"searchQuery"\s*:\s*"([^"]+)"').firstMatch(text);
      if (match != null) {
        final q = match.group(1)?.trim();
        if (q != null && q.isNotEmpty) return q;
      }
      return null;
    }

    // First non-empty line, strip surrounding quotes.
    final line =
        text
            .split(RegExp(r'\r?\n'))
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
            .trim();
    if (line.isEmpty) return null;
    var query = line;
    if ((query.startsWith('"') && query.endsWith('"')) ||
        (query.startsWith("'") && query.endsWith("'"))) {
      query = query.substring(1, query.length - 1).trim();
    }
    if (query.isEmpty || query.length > 200) return null;
    return query;
  }
}
