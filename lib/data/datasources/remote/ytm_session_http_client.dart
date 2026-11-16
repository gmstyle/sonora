import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:http/http.dart' as http;

/// [http.Client] that injects the shared [YTMusic] cookie jar and visitor id
/// into every outbound YouTube request used by `youtube_explode_dart`.
///
/// Catalog browsing already establishes a Music session (`SOCS`, visitor data).
/// Stream resolution used a bare client before; aligning headers reduces the
/// chance that Innertube treats Sonora as a second, anonymous bot identity.
class YtmSessionHttpClient extends http.BaseClient {
  YtmSessionHttpClient({http.Client? inner, YTMusic? ytmusic})
    : _inner = inner ?? http.Client(),
      _ytmusic = ytmusic ?? YTMusic(),
      _ownsInner = inner == null;

  static final Uri _youtubeOrigin = Uri.parse('https://www.youtube.com/');
  static final Uri _musicOrigin = Uri.parse('https://music.youtube.com/');

  final http.Client _inner;
  final YTMusic _ytmusic;
  final bool _ownsInner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _applySession(request);
    final response = await _inner.send(request);
    // Never absorb Set-Cookie from youtubei/player POSTs or CDN GETs — they
    // often clear SAPISID/SID (Max-Age=0) and break the next manifest with
    // "Sign in to confirm you're not a bot". Homepage document GETs still may.
    if (_shouldAbsorbSetCookie(request.url)) {
      await saveSetCookiesFromResponse(
        _ytmusic.cookieJar,
        request.url,
        response,
      );
    }
    return response;
  }

  static bool _shouldAbsorbSetCookie(Uri url) {
    final host = url.host;
    if (host.contains('googlevideo.com')) return false;
    if (url.path.contains('/youtubei/')) return false;
    return host.contains('youtube.com');
  }

  Future<void> _applySession(http.BaseRequest request) async {
    final jar = _ytmusic.cookieJar;
    final byName = <String, String>{};

    void absorb(Iterable<Cookie> cookies) {
      for (final c in cookies) {
        byName[c.name] = c.value;
      }
    }

    absorb(await jar.loadForRequest(request.url));
    absorb(await jar.loadForRequest(_youtubeOrigin));
    absorb(await jar.loadForRequest(_musicOrigin));

    // Always CAI — a login-exported SOCS trips Music's compatibility stub.
    byName['SOCS'] = kYtSocsConsentValue;
    byName.putIfAbsent('CONSENT', () => 'YES+cb');

    final existing = request.headers['cookie'] ?? request.headers['Cookie'];
    if (existing != null && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        final name = trimmed.substring(0, eq);
        byName.putIfAbsent(name, () => trimmed.substring(eq + 1));
      }
    }

    request.headers['cookie'] = byName.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final visitor = _ytmusic.config['VISITOR_DATA'];
    if (visitor != null && visitor.isNotEmpty) {
      request.headers['X-Goog-Visitor-Id'] = visitor;
    }

    // Attach SAPISIDHASH only for Music Innertube. www.youtube.com /player
    // clients (visionos, androidVr) used for streams often return
    // LOGIN_REQUIRED / "not a bot" when Authorization carries a Music
    // USER_SESSION_ID `_u` hash — cookies alone are enough for those clients.
    final path = request.url.path;
    final origin = originOf(request.url.toString());
    if (path.contains('/youtubei/') && origin.contains('music.youtube.com')) {
      final auth = authorizationHeader(
        byName,
        origin,
        userSessionId: _ytmusic.config['USER_SESSION_ID'],
      );
      if (auth != null) {
        request.headers['Authorization'] = auth;
      }
    }
  }

  @override
  void close() {
    if (_ownsInner) {
      _inner.close();
    }
  }
}
