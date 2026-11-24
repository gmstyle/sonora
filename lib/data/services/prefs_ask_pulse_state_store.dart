import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/ask_pulse_state_store.dart';

const kAskPulseSeenReleasesKey = 'askPulseSeenReleases';
const kAskPulseArtistCursorKey = 'askPulseArtistCursor';
const kAskPulseSeenEpisodesKey = 'askPulseSeenEpisodes';
const kAskPulsePodcastCursorKey = 'askPulsePodcastCursor';

class PrefsAskPulseStateStore implements AskPulseStateStore {
  PrefsAskPulseStateStore(this._prefs);

  final SharedPreferences _prefs;

  static const int _maxTrackedArtists = 200;
  static const int _maxReleasesPerArtist = 20;
  static const int _maxTrackedPodcasts = 100;
  static const int _maxEpisodesPerPodcast = 10;

  @override
  Future<Map<String, List<String>>> getSeenReleasesByArtist() async {
    return _readIdMap(kAskPulseSeenReleasesKey);
  }

  @override
  Future<void> saveSeenReleasesByArtist(Map<String, List<String>> seen) async {
    await _writeIdMap(
      kAskPulseSeenReleasesKey,
      seen,
      maxEntries: _maxTrackedArtists,
      maxIdsPerEntry: _maxReleasesPerArtist,
    );
  }

  @override
  Future<int> getArtistCursor() async {
    return _prefs.getInt(kAskPulseArtistCursorKey) ?? 0;
  }

  @override
  Future<void> setArtistCursor(int cursor) async {
    await _prefs.setInt(kAskPulseArtistCursorKey, cursor < 0 ? 0 : cursor);
  }

  @override
  Future<Map<String, List<String>>> getSeenEpisodesByPodcast() async {
    return _readIdMap(kAskPulseSeenEpisodesKey);
  }

  @override
  Future<void> saveSeenEpisodesByPodcast(Map<String, List<String>> seen) async {
    await _writeIdMap(
      kAskPulseSeenEpisodesKey,
      seen,
      maxEntries: _maxTrackedPodcasts,
      maxIdsPerEntry: _maxEpisodesPerPodcast,
    );
  }

  @override
  Future<int> getPodcastCursor() async {
    return _prefs.getInt(kAskPulsePodcastCursorKey) ?? 0;
  }

  @override
  Future<void> setPodcastCursor(int cursor) async {
    await _prefs.setInt(kAskPulsePodcastCursorKey, cursor < 0 ? 0 : cursor);
  }

  Map<String, List<String>> _readIdMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final k = entry.key.toString().trim();
        final v = entry.value;
        if (k.isEmpty || v is! List) continue;
        final ids = v
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        out[k] = ids;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeIdMap(
    String key,
    Map<String, List<String>> map, {
    required int maxEntries,
    required int maxIdsPerEntry,
  }) async {
    final keys = map.keys.toList();
    final trimmedKeys = keys.length > maxEntries
        ? keys.sublist(keys.length - maxEntries)
        : keys;
    final out = <String, List<String>>{};
    for (final k in trimmedKeys) {
      final ids = (map[k] ?? const []).where((s) => s.isNotEmpty).toList();
      out[k] = ids.length > maxIdsPerEntry
          ? ids.sublist(0, maxIdsPerEntry)
          : ids;
    }
    await _prefs.setString(key, jsonEncode(out));
  }
}
