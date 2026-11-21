/// A web citation returned with a grounded Ask completion.
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

/// Text completion plus optional web sources from search grounding.
class GroundedLlmResult {
  const GroundedLlmResult({required this.text, this.sources = const []});

  final String text;
  final List<GroundedSource> sources;

  bool get hasSources => sources.isNotEmpty;
}

/// Extracts unique web sources from DeepSeek Chat Completions payloads
/// (`annotations`, `server_tool_calls` / `server_tool_results`, `citations`,
/// `search_results`) as well as legacy Gemini `groundingMetadata` chunks.
List<GroundedSource> extractGroundedSources(Map<String, dynamic>? raw) {
  if (raw == null) return const [];

  final out = <GroundedSource>[];
  final seen = <String>{};

  void addSource(dynamic rawUri, dynamic rawTitle) {
    final uri = rawUri?.toString().trim() ?? '';
    if (uri.isEmpty || seen.contains(uri)) return;
    seen.add(uri);
    final title = rawTitle?.toString().trim();
    out.add(
      GroundedSource(
        uri: uri,
        title: (title == null || title.isEmpty) ? null : title,
      ),
    );
  }

  void collectFromList(dynamic list) {
    if (list is! List) return;
    for (final entry in list) {
      if (entry is String) {
        addSource(entry, null);
        continue;
      }
      if (entry is! Map) continue;
      final citation = entry['url_citation'];
      if (citation is Map) {
        addSource(citation['url'] ?? citation['uri'], citation['title']);
        continue;
      }
      addSource(
        entry['url'] ?? entry['uri'] ?? entry['link'],
        entry['title'] ?? entry['name'],
      );
    }
  }

  // DeepSeek / OpenAI Chat Completions annotations & server_tool_calls.
  final choices = raw['choices'];
  if (choices is List && choices.isNotEmpty) {
    final firstChoice = choices.first;
    if (firstChoice is Map) {
      final message = firstChoice['message'];
      if (message is Map) {
        collectFromList(message['annotations']);
        collectFromList(message['citations']);
        final serverToolCalls = message['server_tool_calls'];
        if (serverToolCalls is List) {
          for (final call in serverToolCalls) {
            if (call is! Map) continue;
            collectFromList(call['results']);
            collectFromList(call['search_results']);
          }
        }
        collectFromList(message['server_tool_results']);
      }
    }
  }

  // Top-level citations / search_results extensions.
  collectFromList(raw['citations']);
  collectFromList(raw['search_results']);

  // Legacy Gemini groundingMetadata compatibility.
  final candidates = raw['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final first = candidates.first;
    if (first is Map) {
      final meta = first['groundingMetadata'];
      if (meta is Map) {
        final chunks = meta['groundingChunks'];
        if (chunks is List) {
          for (final chunk in chunks) {
            if (chunk is! Map) continue;
            final web = chunk['web'];
            if (web is! Map) continue;
            addSource(web['uri'] ?? web['url'], web['title']);
          }
        }
      }
    }
  }

  return out;
}
