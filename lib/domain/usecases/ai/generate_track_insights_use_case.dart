import '../../repositories/grounded_llm_repository.dart';
import 'track_insights_parser.dart';

const kAskTrackInsightsSystemInstruction = r'''
You research a music track currently playing and return short curiosity bullets grounded in web sources.
Reply with ONLY a single JSON object, no markdown, no commentary.
Schema:
{
  "bullets": ["string — 3 to 5 short factual bullets in the user's language"]
}
Rules:
- Prefer Wikipedia and other encyclopedic / reputable music sources.
- Only state facts you can support from search results.
- If you cannot find reliable information, return {"bullets":[]}.
- Never invent video IDs, URLs, award years, or chart positions you are unsure about.
- Do not reproduce copyrighted lyrics.
- Keep each bullet under ~160 characters.
''';

/// Cloud-only: grounded curiosities for the now-playing track.
class GenerateTrackInsightsUseCase {
  GenerateTrackInsightsUseCase(
    this._llm, {
    TrackInsightsParser parser = const TrackInsightsParser(),
  }) : _parser = parser;

  final GroundedLlmRepository _llm;
  final TrackInsightsParser _parser;

  Future<TrackInsights?> execute({
    required String title,
    required String artist,
    String? album,
    required String locale,
  }) async {
    if (!await _llm.isReady()) return null;

    final albumLine =
        (album != null && album.trim().isNotEmpty)
            ? 'Album: ${album.trim()}\n'
            : '';
    final userMessage =
        'Output language (BCP-47 / language code): $locale\n'
        'Title: $title\n'
        'Artist: $artist\n'
        '$albumLine'
        'Write 3–5 short curiosity bullets about this track, artist, or album.';

    try {
      final grounded = await _llm.completeGrounded(
        systemInstruction: kAskTrackInsightsSystemInstruction,
        userMessage: userMessage,
        maxOutputTokens: 1024,
      );
      final parsed = _parser.parse(grounded.text, sources: grounded.sources);
      if (parsed == null || parsed.isEmpty) return null;
      // Plan: no sources → soft fail (do not show ungrounded prose).
      if (!grounded.hasSources) return null;
      return TrackInsights(bullets: parsed.bullets, sources: grounded.sources);
    } catch (_) {
      return null;
    }
  }
}
