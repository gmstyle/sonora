import 'dart:convert';

class BackupData {
  final List<Map<String, dynamic>> likedSongs;
  final List<Map<String, dynamic>> followedArtists;
  final List<Map<String, dynamic>> playlists;
  final Map<String, List<Map<String, dynamic>>> playlistEntries;
  final Map<String, dynamic>? settings;

  const BackupData({
    this.likedSongs = const [],
    this.followedArtists = const [],
    this.playlists = const [],
    this.playlistEntries = const {},
    this.settings,
  });
}

String serializeBackup(BackupData data) {
  return jsonEncode({
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'likedSongs': data.likedSongs,
    'followedArtists': data.followedArtists,
    'playlists': data.playlists,
    'playlistEntries': data.playlistEntries,
    'settings': data.settings,
  });
}

BackupData deserializeBackup(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  return BackupData(
    likedSongs:
        (map['likedSongs'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
    followedArtists:
        (map['followedArtists'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
    playlists:
        (map['playlists'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
    playlistEntries:
        (map['playlistEntries'] as Map<String, dynamic>?)
                ?.map(
                  (k, v) => MapEntry(
                    k,
                    (v as List<dynamic>).cast<Map<String, dynamic>>(),
                  ),
                ) ??
            {},
    settings: map['settings'] as Map<String, dynamic>?,
  );
}
