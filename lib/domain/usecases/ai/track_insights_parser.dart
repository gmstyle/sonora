import 'dart:convert';

import '../../models/grounded_llm_result.dart';

/// Parsed track insights from a grounded Gemini JSON body + sources.
class TrackInsights {
  const TrackInsights({required this.bullets, this.sources = const []});

  final List<String> bullets;
  final List<GroundedSource> sources;

  bool get isEmpty => bullets.isEmpty;
}

/// Parses LLM JSON `{ "bullets": ["..."] }` into [TrackInsights].
class TrackInsightsParser {
  const TrackInsightsParser();

  TrackInsights? parse(String raw, {List<GroundedSource> sources = const []}) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) return null;

    late final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final bulletsRaw = decoded['bullets'];
    if (bulletsRaw is! List) return null;

    final bullets = bulletsRaw
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .take(8)
        .toList(growable: false);

    if (bullets.isEmpty) return null;
    return TrackInsights(bullets: bullets, sources: sources);
  }

  String? _extractJsonObject(String raw) {
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
    return text.substring(start, end + 1);
  }
}
