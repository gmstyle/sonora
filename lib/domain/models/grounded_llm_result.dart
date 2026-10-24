/// A web citation returned with a grounded Gemini completion.
class GroundedSource {
  const GroundedSource({required this.uri, this.title});

  final String uri;
  final String? title;

  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    try {
      return Uri.parse(uri).host;
    } catch (_) {
      return uri;
    }
  }
}

/// Text completion plus optional web sources from Google Search grounding.
class GroundedLlmResult {
  const GroundedLlmResult({required this.text, this.sources = const []});

  final String text;
  final List<GroundedSource> sources;

  bool get hasSources => sources.isNotEmpty;
}

/// Extracts unique web sources from a Genkit Gemini [raw] GenerateContent
/// payload (`candidates[0].groundingMetadata.groundingChunks`).
List<GroundedSource> extractGroundedSources(Map<String, dynamic>? raw) {
  if (raw == null) return const [];

  final candidates = raw['candidates'];
  if (candidates is! List || candidates.isEmpty) return const [];

  final first = candidates.first;
  if (first is! Map) return const [];

  final meta = first['groundingMetadata'];
  if (meta is! Map) return const [];

  final chunks = meta['groundingChunks'];
  if (chunks is! List) return const [];

  final out = <GroundedSource>[];
  final seen = <String>{};

  for (final chunk in chunks) {
    if (chunk is! Map) continue;
    final web = chunk['web'];
    if (web is! Map) continue;
    final uri = web['uri']?.toString().trim() ?? '';
    if (uri.isEmpty || seen.contains(uri)) continue;
    seen.add(uri);
    final title = web['title']?.toString().trim();
    out.add(
      GroundedSource(
        uri: uri,
        title: (title == null || title.isEmpty) ? null : title,
      ),
    );
  }

  return out;
}
