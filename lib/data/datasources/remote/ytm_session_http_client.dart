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

  static bool _isCookielessClientRequest(http.BaseRequest request) {
    final clientName =
        request.headers['X-Youtube-Client-Name'] ??
        request.headers['x-youtube-client-name'];
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
    if (_isCookielessClientRequest(request)) {
      // Native/headset clients (VISIONOS, ANDROID_VR, IOS, ANDROID) must not
      // receive browser login cookies or web VISITOR_DATA; mixing them trips
      // YouTube's "Sign in to confirm you're not a bot" check.
      request.headers.remove('cookie');
      request.headers.remove('Cookie');
      request.headers.remove('X-Goog-Visitor-Id');
      request.headers.remove('x-goog-visitor-id');
      request.headers.remove('Authorization');
      request.headers.remove('authorization');
      return _inner.send(request);
    }

    await _applySession(request);
    final response = await _inner.send(request);
    // Absorb valid Set-Cookie rotations from authenticated youtube.com calls;
    // saveSetCookiesFromResponse ignores empty / Max-Age<=0 session wipes.
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
    return host.contains('youtube.com');
  }

  Future<void> _applySession(http.BaseRequest request) async {
    final jar = _ytmusic.cookieJar;
    final byName = <String, String>{};

    void absorb(Iterable<Cookie> cookies) {
      for (final c in cookies) {
        if (c.value.isEmpty) continue;
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
    request.headers.remove('Cookie');
    if (existing != null && existing.isNotEmpty) {
      for (final part in existing.split(';')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eq = trimmed.indexOf('=');
        if (eq <= 0) continue;
        final name = trimmed.substring(0, eq);
        final value = trimmed.substring(eq + 1);
        if (value.isEmpty) continue;
        byName.putIfAbsent(name, () => value);
      }
    }

    request.headers['cookie'] = byName.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final existingVisitor =
        request.headers['X-Goog-Visitor-Id'] ??
        request.headers['x-goog-visitor-id'];
    if (existingVisitor == null || existingVisitor.isEmpty) {
      final visitor = _ytmusic.config['VISITOR_DATA'];
      if (visitor != null && visitor.isNotEmpty) {
        request.headers['X-Goog-Visitor-Id'] = visitor;
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
        request.headers['Authorization'] = auth;
        request.headers['X-Youtube-Bootstrap-Logged-In'] = 'true';
        final sessionIndex = _ytmusic.config['SESSION_INDEX'];
        request.headers['X-Goog-AuthUser'] =
            (sessionIndex != null && sessionIndex.isNotEmpty)
            ? sessionIndex
            : '0';
        final delegatedId = _ytmusic.config['DELEGATED_SESSION_ID'];
        if (delegatedId != null && delegatedId.isNotEmpty) {
          request.headers['X-Goog-PageId'] = delegatedId;
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
