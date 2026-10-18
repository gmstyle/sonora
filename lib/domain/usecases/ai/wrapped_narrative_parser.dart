import 'dart:convert';

import '../../models/wrapped_narrative.dart';

/// Parses cloud LLM JSON into [WrappedNarrative].
class WrappedNarrativeParser {
  const WrappedNarrativeParser();

  WrappedNarrative? parse(String raw) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) return null;
    late final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);

    final title = _string(map['title']);
    final hook = _string(map['hook']);
    final closing = _string(map['closing']);
    if (title == null || hook == null || closing == null) return null;
    if (title.isEmpty || hook.isEmpty || closing.isEmpty) return null;

    final artistLine = _string(map['artistLine']);
    final songLine = _string(map['songLine']);

    return WrappedNarrative(
      title: title,
      hook: hook,
      artistLine:
          (artistLine == null || artistLine.isEmpty) ? null : artistLine,
      songLine: (songLine == null || songLine.isEmpty) ? null : songLine,
      closing: closing,
      fromAi: true,
    );
  }

  static String? _string(Object? v) {
    if (v is String) return v.trim();
    return null;
  }

  static String? _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('```')) {
      final firstNl = text.indexOf('\n');
      if (firstNl != -1) text = text.substring(firstNl + 1);
      final fence = text.lastIndexOf('```');
      if (fence != -1) text = text.substring(0, fence);
      text = text.trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }
}
