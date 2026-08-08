import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../domain/models/media_quality.dart';
import '../../domain/models/stream_role.dart';
import '../datasources/remote/stream_datasource.dart';
import 'media_cache_service.dart';

/// Local HTTP Proxy Server running on 127.0.0.1.
///
/// Acts as a resilient buffer between `media_kit` (libmpv) and YouTube Music
/// remote streams. Responsibilities:
/// - Serves locally cached audio files directly from disk if available
/// - Supports HTTP Range requests for instant seek/scrubbing
/// - Transparently fetches remote stream URLs via [StreamDatasource]
/// - Retries and auto-refreshes expired/rate-limited YouTube URLs (HTTP 403/429)
///   without throwing unrecoverable errors to `media_kit`
class LocalAudioProxyServer {
  final StreamDatasource _streamDatasource;
  final MediaCacheService _mediaCacheService;

  HttpServer? _server;

  LocalAudioProxyServer({
    required StreamDatasource streamDatasource,
    MediaCacheService? mediaCacheService,
  }) : _streamDatasource = streamDatasource,
       _mediaCacheService = mediaCacheService ?? MediaCacheService.instance;

  /// Active port allocated by the OS, or 0 if not running.
  int get port => _server?.port ?? 0;

  /// Base URL of the local proxy server (e.g. `http://127.0.0.1:45123`).
  String get streamBaseUrl => 'http://127.0.0.1:$port';

  /// Whether the local server is currently active.
  bool get isRunning => _server != null;

  StreamDatasource get streamDatasource => _streamDatasource;

  /// Starts the HTTP server on loopback IPv4 (127.0.0.1) on an available port.
  Future<void> start() async {
    if (_server != null) return;

    final app = Router();
    app.get('/stream', _handleStream);

    try {
      _server = await shelf_io.serve(
        app.call,
        InternetAddress.loopbackIPv4,
        0, // Port 0 lets the OS assign an available ephemeral port
      );
      dev.log('[LocalAudioProxyServer] Server started at $streamBaseUrl');
    } catch (e) {
      dev.log('[LocalAudioProxyServer] Failed to start server: $e');
      rethrow;
    }
  }

  /// Stops the local HTTP server.
  Future<void> stop() async {
    if (_server == null) return;
    await _server?.close(force: true);
    _server = null;
    dev.log('[LocalAudioProxyServer] Server stopped');
  }

  /// Constructs a local proxy stream URL for a given [videoId].
  ///
  /// [audioQuality], [videoQuality], [preferVideo], and [role] are forwarded
  /// as query params (`qa`/`qv`/`v`/`kind`) so the handler can resolve the
  /// correct YouTube stream when media_kit requests it.
  String getStreamUrlForVideo(
    String videoId, {
    MediaQuality audioQuality = MediaQuality.high,
    MediaQuality videoQuality = MediaQuality.high,
    bool preferVideo = false,
    StreamRole role = StreamRole.primary,
  }) {
    if (!isRunning) {
      dev.log(
        '[LocalAudioProxyServer] WARNING: Server requested before start() was called!',
      );
    }
    final params = <String, String>{
      'videoId': videoId,
      'qa': audioQuality.storageValue,
      'qv': videoQuality.storageValue,
      if (preferVideo) 'v': '1',
      if (role != StreamRole.primary) 'kind': role.name,
    };
    return Uri.parse(
      '$streamBaseUrl/stream',
    ).replace(queryParameters: params).toString();
  }

  static StreamRole _roleFromQuery(String? kind) {
    return switch (kind) {
      'video' => StreamRole.video,
      'audio' => StreamRole.audio,
      _ => StreamRole.primary,
    };
  }

  /// Resolves audio/video quality from `qa`/`qv`, falling back to legacy `q`.
  static (MediaQuality audio, MediaQuality video) _qualitiesFromQuery(
    Map<String, String> params,
  ) {
    final legacy = params['q'];
    final audio = MediaQuality.fromStorage(params['qa'] ?? legacy);
    final video = MediaQuality.fromStorage(params['qv'] ?? legacy);
    return (audio, video);
  }

  /// Route handler for `/stream?videoId=...&qa=...&qv=...&v=...&kind=...`
  Future<Response> _handleStream(Request request) async {
    final videoId = request.url.queryParameters['videoId'];
    if (videoId == null || videoId.isEmpty) {
      return Response.badRequest(body: 'Missing videoId parameter');
    }

    final (audioQuality, videoQuality) = _qualitiesFromQuery(
      request.url.queryParameters,
    );
    final preferVideo = request.url.queryParameters['v'] == '1';
    final role = _roleFromQuery(request.url.queryParameters['kind']);
    final rangeHeaderStr = request.headers['range'];

    // Skip disk cache for adaptive video playback (video-only is large / wrong
    // MIME; adaptive audio must not be stored under bare videoId or it poisons
    // PlayVideoIdUseCase / toMedia into treating an audio file as the source).
    final allowDiskCache = role != StreamRole.video && !preferVideo;

    if (allowDiskCache) {
      try {
        final cachedUri = await _mediaCacheService.getCachedFileUri(videoId);
        if (cachedUri != null) {
          final filePath = Uri.parse(cachedUri).toFilePath();
          final file = File(filePath);
          if (await file.exists()) {
            dev.log('[LocalAudioProxyServer] Serving $videoId from disk cache');
            return await _serveLocalFile(file, rangeHeaderStr);
          }
        }
      } catch (e) {
        dev.log(
          '[LocalAudioProxyServer] Error checking local cache for $videoId: $e',
        );
      }
    }

    String? streamUrl;
    try {
      streamUrl = await _streamDatasource.getStreamUrl(
        videoId,
        audioQuality: audioQuality,
        videoQuality: videoQuality,
        preferVideo: preferVideo,
        role: role,
      );
    } catch (e) {
      dev.log(
        '[LocalAudioProxyServer] Failed to resolve stream URL for $videoId '
        '(qa=${audioQuality.storageValue}, qv=${videoQuality.storageValue}, '
        'v=$preferVideo, role=${role.name}): $e',
      );
      return Response.internalServerError(
        body: 'Failed to resolve stream URL: $e',
      );
    }

    return await _proxyRemoteStream(
      videoId,
      streamUrl,
      rangeHeaderStr,
      audioQuality: audioQuality,
      videoQuality: videoQuality,
      preferVideo: preferVideo,
      role: role,
      allowDiskCache: allowDiskCache,
    );
  }

  /// Serves a local disk file with full HTTP Range request support.
  Future<Response> _serveLocalFile(File file, String? rangeHeaderStr) async {
    final fileLength = await file.length();
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'webm' ? 'audio/webm' : 'audio/mpeg';

    if (rangeHeaderStr != null && rangeHeaderStr.startsWith('bytes=')) {
      final rangeValue = rangeHeaderStr.substring(6).trim();
      final parts = rangeValue.split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end =
          (parts.length > 1 && parts[1].isNotEmpty)
              ? int.tryParse(parts[1]) ?? (fileLength - 1)
              : (fileLength - 1);

      final safeEnd = end >= fileLength ? fileLength - 1 : end;
      final safeStart = start > safeEnd ? 0 : start;
      final contentLength = safeEnd - safeStart + 1;

      final stream = file.openRead(safeStart, safeEnd + 1);

      return Response(
        206, // Partial Content
        body: stream,
        headers: {
          'Content-Type': contentType,
          'Content-Length': contentLength.toString(),
          'Content-Range': 'bytes $safeStart-$safeEnd/$fileLength',
          'Accept-Ranges': 'bytes',
        },
      );
    }

    return Response.ok(
      file.openRead(),
      headers: {
        'Content-Type': contentType,
        'Content-Length': fileLength.toString(),
        'Accept-Ranges': 'bytes',
      },
    );
  }

  /// Proxies a remote YouTube stream to the local client (`media_kit`).
  ///
  /// Retries up to 3 times with fresh URL resolution if YouTube responds with
  /// HTTP 403 (expired token), HTTP 429 (rate limited), or a socket error.
  Future<Response> _proxyRemoteStream(
    String videoId,
    String initialUrl,
    String? rangeHeaderStr, {
    required MediaQuality audioQuality,
    required MediaQuality videoQuality,
    required bool preferVideo,
    required StreamRole role,
    required bool allowDiskCache,
  }) async {
    int attempts = 0;
    String currentUrl = initialUrl;

    while (attempts < 3) {
      attempts++;
      HttpClient? client;
      try {
        client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final request = await client.getUrl(Uri.parse(currentUrl));

        if (rangeHeaderStr != null) {
          request.headers.set(HttpHeaders.rangeHeader, rangeHeaderStr);
        }

        final response = await request.close();

        if (response.statusCode == 403 ||
            response.statusCode == 429 ||
            response.statusCode >= 500) {
          dev.log(
            '[LocalAudioProxyServer] Remote stream returned HTTP ${response.statusCode} for $videoId (attempt $attempts). Refreshing URL...',
          );
          client.close();
          _streamDatasource.invalidateCache(videoId);
          currentUrl = await _streamDatasource.getStreamUrl(
            videoId,
            audioQuality: audioQuality,
            videoQuality: videoQuality,
            preferVideo: preferVideo,
            role: role,
          );
          continue;
        }

        final headers = <String, String>{'Accept-Ranges': 'bytes'};

        final cType = response.headers.value(HttpHeaders.contentTypeHeader);
        if (cType != null) headers['Content-Type'] = cType;

        final cLen = response.headers.value(HttpHeaders.contentLengthHeader);
        if (cLen != null) headers['Content-Length'] = cLen;

        final cRange = response.headers.value(HttpHeaders.contentRangeHeader);
        if (cRange != null) headers['Content-Range'] = cRange;

        if (allowDiskCache &&
            (rangeHeaderStr == null || rangeHeaderStr.startsWith('bytes=0-'))) {
          unawaited(_mediaCacheService.downloadToCache(videoId, currentUrl));
        }

        return Response(response.statusCode, body: response, headers: headers);
      } catch (e) {
        client?.close();
        dev.log(
          '[LocalAudioProxyServer] Exception proxying stream for $videoId (attempt $attempts): $e',
        );
        if (attempts >= 3) {
          return Response.internalServerError(
            body: 'Stream proxy error after 3 attempts: $e',
          );
        }
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          _streamDatasource.invalidateCache(videoId);
          currentUrl = await _streamDatasource.getStreamUrl(
            videoId,
            audioQuality: audioQuality,
            videoQuality: videoQuality,
            preferVideo: preferVideo,
            role: role,
          );
        } catch (_) {}
      }
    }

    return Response.internalServerError(
      body: 'Failed to proxy remote stream for $videoId',
    );
  }
}
