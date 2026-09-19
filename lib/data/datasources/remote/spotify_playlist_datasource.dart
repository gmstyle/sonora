import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../domain/models/playlist_import.dart';

/// Reads public Spotify playlist metadata from the embed page.
///
/// No Spotify API key or user login is required. Private / unlisted
/// playlists cannot be imported. The embed payload typically includes up
/// to ~100 tracks; longer playlists are imported truncated.
class SpotifyPlaylistDatasource {
  SpotifyPlaylistDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              followRedirects: true,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml',
                'Accept-Language': 'en-US,en;q=0.9',
              },
            ),
          );

  final Dio _dio;

  static final _nextData = RegExp(
    r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
    dotAll: true,
  );

  /// Embed pages usually cap the inline track list around this size.
  static const embedTrackCap = 100;

  Future<SpotifyPlaylistSnapshot> fetchPlaylist(String playlistId) async {
    try {
      final response = await _dio.get<String>(
        'https://open.spotify.com/embed/playlist/$playlistId',
        queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
        ),
      );
      final status = response.statusCode ?? 0;
      final html = response.data;
      if (status >= 400 || html == null || html.isEmpty) {
        throw Exception('The playlist is empty or could not be retrieved');
      }
      return parseEmbedHtml(html);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse &&
          (e.response?.statusCode ?? 0) >= 400) {
        throw Exception('The playlist is empty or could not be retrieved');
      }
      rethrow;
    }
  }

  /// Parses `__NEXT_DATA__` from a Spotify embed HTML document.
  static SpotifyPlaylistSnapshot parseEmbedHtml(String html) {
    final match = _nextData.firstMatch(html);
    if (match == null || match.group(1) == null) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    final entity =
        _asMap(
          _asMap(
            _asMap(_asMap(json['props'])?['pageProps'])?['state'],
          )?['data'],
        )?['entity'];
    final entityMap = _asMap(entity);
    if (entityMap == null || entityMap['type'] != 'playlist') {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    final id = (entityMap['id'] as String?)?.trim() ?? '';
    final name =
        ((entityMap['name'] ?? entityMap['title']) as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    final rawTracks = entityMap['trackList'];
    final tracks = <SpotifyPlaylistTrack>[];
    if (rawTracks is List) {
      for (final item in rawTracks) {
        final track = _asMap(item);
        if (track == null) continue;
        final entityType = track['entityType'] as String? ?? 'track';
        if (entityType != 'track') continue;
        final title = (track['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) continue;
        tracks.add(
          SpotifyPlaylistTrack(
            title: title,
            subtitle: (track['subtitle'] as String?) ?? '',
            durationMs: (track['duration'] as num?)?.toInt(),
            isExplicit: track['isExplicit'] as bool? ?? false,
            uri: track['uri'] as String?,
          ),
        );
      }
    }

    if (tracks.isEmpty) {
      throw Exception('The playlist is empty or could not be retrieved');
    }

    return SpotifyPlaylistSnapshot(
      id: id,
      name: name,
      tracks: tracks,
      truncated: tracks.length >= embedTrackCap,
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
