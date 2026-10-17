import 'dart:convert';

import '../../models/music_search_intent.dart';

/// Parses LLM output into [MusicSearchIntent]. Pure Dart — unit-testable.
class MusicSearchIntentParser {
  const MusicSearchIntentParser();

  /// Extracts the first JSON object from [raw] (tolerates markdown fences /
  /// thinking preamble) and maps it to an intent.
  ///
  /// Returns null when the payload is missing, invalid, or has an empty query.
  MusicSearchIntent? parse(String raw) {
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
    final searchQuery = _string(map['searchQuery']) ?? _composeQuery(map);
    if (searchQuery == null || searchQuery.trim().isEmpty) return null;

    return MusicSearchIntent(
      searchQuery: searchQuery.trim(),
      mood: _string(map['mood']),
      genres: _stringList(map['genres']),
      era: _string(map['era']),
      seedArtists: _stringList(map['seedArtists']),
      contentType: _contentType(_string(map['contentType'])),
    );
  }

  String? _composeQuery(Map<String, dynamic> map) {
    final parts = <String>[
      ..._stringList(map['genres']),
      if (_string(map['era']) != null) _string(map['era'])!,
      ..._stringList(map['seedArtists']),
      if (_string(map['mood']) != null) _string(map['mood'])!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  MusicSearchContentType _contentType(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'songs':
      case 'song':
      case 'track':
      case 'tracks':
        return MusicSearchContentType.songs;
      case 'artists':
      case 'artist':
        return MusicSearchContentType.artists;
      case 'albums':
      case 'album':
        return MusicSearchContentType.albums;
      case 'playlists':
      case 'playlist':
        return MusicSearchContentType.playlists;
      case 'podcasts':
      case 'podcast':
        return MusicSearchContentType.podcasts;
      case 'episodes':
      case 'episode':
        return MusicSearchContentType.episodes;
      default:
        return MusicSearchContentType.any;
    }
  }

  String? _string(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
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
