import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:http/http.dart' as http;

import 'youtube_client_policy.dart';

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

  static void _removeHeaderCaseInsensitive(
    Map<String, String> headers,
    String name,
  ) {
    final lower = name.toLowerCase();
    headers.removeWhere((key, _) => key.toLowerCase() == lower);
  }

  static void _setHeaderCaseInsensitive(
    Map<String, String> headers,
    String name,
    String value,
  ) {
    _removeHeaderCaseInsensitive(headers, name);
    headers[name] = value;
  }

  static String? _headerValueCaseInsensitive(
    Map<String, String> headers,
    String name,
  ) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }

  static bool _isCookielessClientRequest(http.BaseRequest request) {
    final path = request.url.path;
    if (path == '/sw.js_data' || path.endsWith('/youtubei/v1/visitor_id')) {
      return true;
    }
    final clientName = _headerValueCaseInsensitive(
      request.headers,
      'X-Youtube-Client-Name',
    );
    if (YoutubeClientPolicy.isCookielessClient(clientName)) {
      return true;
    }
    if (request.url.host.contains('googlevideo.com')) {
      return YoutubeClientPolicy.isCookielessClient(
        YoutubeClientPolicy.streamClientName(request.url),
      );
    }
    return false;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host.contains('googlevideo.com')) {
      _setHeaderCaseInsensitive(
        request.headers,
        'User-Agent',
        YoutubeClientPolicy.userAgentForStreamUrl(request.url),
      );
    }

    if (_isCookielessClientRequest(request)) {
      // Strip browser cookies, auth, and web Origin headers on native
      // cookieless clients and anonymous visitorData endpoints while
      // preserving any anonymous X-Goog-Visitor-Id attached by the caller.
      for (final header in const [
        'cookie',
        'authorization',
        'x-youtube-bootstrap-logged-in',
        'x-goog-authuser',
        'x-goog-pageid',
        'origin',
        'x-origin',
      ]) {
        _removeHeaderCaseInsensitive(request.headers, header);
      }
      return _inner.send(request);
    }

    await _applySession(request);
    final response = await _inner.send(request);
    // Absorb valid Set-Cookie rotations from authenticated youtube.com calls;
    // saveSetCookiesFromResponse ignores empty / Max-Age<=0 session wipes
    // except explicit LOGIN_INFO wipes (server-side revocation).
    if (_shouldAbsorbSetCookie(request.url)) {
      await saveSetCookiesFromResponse(
        _ytmusic.cookieJar,
        request.url,
        response,
        onSessionCookiesChanged: _ytmusic.onSessionCookiesChanged,
        onLoginInfoWiped: () async {
          for (final key in const [
            'USER_SESSION_ID',
            'SESSION_INDEX',
            'DELEGATED_SESSION_ID',
            'DATASYNC_ID',
            'LOGGED_IN',
          ]) {
            _ytmusic.config[key] = '';
          }
          final revoked = _ytmusic.onSessionRevoked;
          if (revoked != null) {
            await revoked();
          }
        },
      );
    }
    return response;
  }

  static bool _shouldAbsorbSetCookie(Uri url) {
    final host = url.host;
    if (host.contains('googlevideo.com')) return false;
    return host.contains('youtube.com');
  }

  Future<void> _applySession(http.BaseRequest request) async {
    final jar = _ytmusic.cookieJar;
    final byName = <String, String>{};

    void absorb(Iterable<Cookie> cookies) {
      for (final c in cookies) {
        if (c.value.isEmpty) continue;
        byName.putIfAbsent(c.name, () => c.value);
      }
    }

    absorb(await jar.loadForRequest(request.url));
    absorb(await jar.loadForRequest(_youtubeOrigin));
    absorb(await jar.loadForRequest(_musicOrigin));

    // Always CAI — a login-exported SOCS trips Music's compatibility stub.
    byName['SOCS'] = kYtSocsConsentValue;
    byName.putIfAbsent('CONSENT', () => 'YES+cb');

    final existing = _headerValueCaseInsensitive(request.headers, 'cookie');
    _removeHeaderCaseInsensitive(request.headers, 'cookie');
    if (existing != null && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        final name = trimmed.substring(0, eq).trim();
        final value = trimmed.substring(eq + 1).trim();
        if (name.isEmpty || value.isEmpty) continue;
        byName.putIfAbsent(name, () => value);
      }
    }

    request.headers['cookie'] = formatCookieHeader(byName);

    final existingVisitor = _headerValueCaseInsensitive(
      request.headers,
      'x-goog-visitor-id',
    );
    if (existingVisitor == null || existingVisitor.isEmpty) {
      final visitor = _ytmusic.config['VISITOR_DATA'];
      if (visitor != null && visitor.isNotEmpty) {
        _setHeaderCaseInsensitive(
          request.headers,
          'X-Goog-Visitor-Id',
          visitor,
        );
      }
    }

    // Cookie-authenticated youtubei clients (WEB_REMIX on music.youtube.com,
    // TVHTML5 / WEB / MWEB on www.youtube.com) need SAPISIDHASH bound to the
    // request origin. Only Music uses Music's USER_SESSION_ID `_u` suffix.
    final path = request.url.path;
    final origin = originOf(request.url.toString());
    final isMusic = origin == 'https://music.youtube.com';
    if (path.contains('/youtubei/') &&
        (isMusic || origin == 'https://www.youtube.com')) {
      final auth = authorizationHeader(
        byName,
        origin,
        userSessionId: isMusic ? _ytmusic.config['USER_SESSION_ID'] : null,
      );
      if (auth != null) {
        _setHeaderCaseInsensitive(request.headers, 'Authorization', auth);
        _setHeaderCaseInsensitive(
          request.headers,
          'X-Youtube-Bootstrap-Logged-In',
          'true',
        );
        final sessionIndex = _ytmusic.config['SESSION_INDEX'];
        _setHeaderCaseInsensitive(
          request.headers,
          'X-Goog-AuthUser',
          (sessionIndex != null && sessionIndex.isNotEmpty)
              ? sessionIndex
              : '0',
        );
        _setHeaderCaseInsensitive(request.headers, 'X-Origin', origin);
        final delegatedId = _ytmusic.config['DELEGATED_SESSION_ID'];
        if (delegatedId != null && delegatedId.isNotEmpty) {
          _setHeaderCaseInsensitive(
            request.headers,
            'X-Goog-PageId',
            delegatedId,
          );
        }
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
