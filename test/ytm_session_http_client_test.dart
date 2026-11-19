import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonora/data/datasources/remote/youtube_client_policy.dart';
import 'package:sonora/data/datasources/remote/ytm_session_http_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  late YTMusic yt;

  setUp(() async {
    yt = YTMusic();
    await clearAuthCookies(yt.cookieJar);
    yt.config.clear();
    yt.config['VISITOR_DATA'] = 'visitor-web-1';
    yt.config['USER_SESSION_ID'] = 'user-session-42';
    yt.config['SESSION_INDEX'] = '1';
    yt.config['DELEGATED_SESSION_ID'] = 'delegated-99';

    await applyAuthCookies(yt.cookieJar, [
      Cookie('SAPISID', 'test-sapisid')..domain = '.youtube.com',
      Cookie('LOGIN_INFO', 'test-login-info')..domain = '.youtube.com',
    ]);
  });

  tearDown(() async {
    await clearAuthCookies(yt.cookieJar);
    yt.config.clear();
  });

  test('strips cookies and auth while preserving anonymous visitor id on cookieless clients and visitorData endpoints', () async {
    final recorded = <http.BaseRequest>[];
    final inner = MockClient((req) async {
      recorded.add(req);
      return http.Response(
        '{}',
        200,
        headers: {
          'set-cookie': 'YSC=should-ignore; Path=/; Domain=.youtube.com',
        },
        request: req,
      );
    });

    final client = YtmSessionHttpClient(inner: inner, ytmusic: yt);

    for (final clientName in ['VISIONOS', 'ANDROID_VR']) {
      final req =
          http.Request(
              'POST',
              Uri.parse(
                'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
              ),
            )
            ..headers['X-Youtube-Client-Name'] = clientName
            ..headers['cookie'] = 'CONSENT=YES+cb'
            ..headers['Cookie'] = 'SAPISID=leak'
            ..headers['Authorization'] = 'SAPISIDHASH old'
            ..headers['X-Goog-Visitor-Id'] = 'anon-visitor-1'
            ..headers['Origin'] = 'https://www.youtube.com'
            ..headers['X-Origin'] = 'https://www.youtube.com'
            ..headers['X-Youtube-Bootstrap-Logged-In'] = 'true'
            ..headers['X-Goog-AuthUser'] = '0'
            ..headers['X-Goog-PageId'] = 'page-1';

      await client.send(req);
    }

    final visitorIdReq =
        http.Request(
            'POST',
            Uri.parse(
              'https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false',
            ),
          )
          ..headers['Cookie'] = 'SAPISID=leak'
          ..headers['Authorization'] = 'SAPISIDHASH old'
          ..headers['Origin'] = 'https://www.youtube.com';
    await client.send(visitorIdReq);

    final swJsReq =
        http.Request('GET', Uri.parse('https://www.youtube.com/sw.js_data'))
          ..headers['cookie'] = 'SAPISID=leak'
          ..headers['Authorization'] = 'SAPISIDHASH old';
    await client.send(swJsReq);

    final cdnReq =
        http.Request(
            'HEAD',
            Uri.parse(
              'https://rr1.googlevideo.com/videoplayback?c=VISIONOS&itag=140',
            ),
          )
          ..headers['cookie'] = 'CONSENT=YES+cb'
          ..headers['Origin'] = 'https://www.youtube.com'
          ..headers['user-agent'] = 'Mozilla/5.0 Chrome/96.0.4664.18';
    await client.send(cdnReq);

    expect(recorded, hasLength(5));
    for (final req in recorded) {
      expect(req.headers.containsKey('cookie'), isFalse);
      expect(req.headers.containsKey('Cookie'), isFalse);
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(req.headers.containsKey('Origin'), isFalse);
      expect(req.headers.containsKey('X-Origin'), isFalse);
      expect(req.headers.containsKey('X-Youtube-Bootstrap-Logged-In'), isFalse);
      expect(req.headers.containsKey('X-Goog-AuthUser'), isFalse);
      expect(req.headers.containsKey('X-Goog-PageId'), isFalse);
      expect(req.headers['X-Goog-Visitor-Id'], isNot('visitor-web-1'));
    }
    expect(recorded[0].headers['X-Goog-Visitor-Id'], 'anon-visitor-1');
    expect(recorded[1].headers['X-Goog-Visitor-Id'], 'anon-visitor-1');
    expect(recorded[2].headers.containsKey('X-Goog-Visitor-Id'), isFalse);
    expect(recorded[3].headers.containsKey('X-Goog-Visitor-Id'), isFalse);

    final cdnUa = recorded[4].headers.entries
        .where((e) => e.key.toLowerCase() == 'user-agent')
        .toList();
    expect(cdnUa, hasLength(1));
    expect(
      cdnUa.single.value,
      (YoutubeApiClient.visionos.payload['context']
          as Map)['client']['userAgent'],
    );

    final jarCookies = await loadCookieMap(yt.cookieJar, kYoutubeOrigin);
    expect(jarCookies.containsKey('YSC'), isFalse);
  });

  test('attaches SAPISIDHASH without Music _u and auth headers to www.youtube.com TVHTML5', () async {
    late http.BaseRequest sent;
    final inner = MockClient((req) async {
      sent = req;
      return http.Response(
        '{}',
        200,
        headers: {
          'set-cookie':
              'SAPISID=; Max-Age=0; Path=/; Domain=.youtube.com, '
              'SIDCC=fresh-sidcc; Path=/; Domain=.youtube.com; Secure',
        },
        request: req,
      );
    });

    final client = YtmSessionHttpClient(inner: inner, ytmusic: yt);
    final req =
        http.Request(
            'POST',
            Uri.parse(
              'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
            ),
          )
          ..headers['X-Youtube-Client-Name'] = 'TVHTML5'
          ..headers['Cookie'] = 'PREF=hl=en';

    await client.send(req);

    expect(sent.headers.keys.where((k) => k.toLowerCase() == 'cookie'), [
      'cookie',
    ]);
    expect(sent.headers['cookie'], contains('SAPISID=test-sapisid'));
    expect(sent.headers['cookie'], contains('LOGIN_INFO=test-login-info'));
    expect(sent.headers['cookie'], contains('SOCS=CAI'));
    expect(sent.headers['cookie'], contains('PREF=hl=en'));
    expect(sent.headers['X-Goog-Visitor-Id'], 'visitor-web-1');
    expect(sent.headers['Authorization'], startsWith('SAPISIDHASH '));
    expect(sent.headers['Authorization'], isNot(contains('_u')));
    expect(sent.headers['X-Youtube-Bootstrap-Logged-In'], 'true');
    expect(sent.headers['X-Goog-AuthUser'], '1');
    expect(sent.headers['X-Goog-PageId'], 'delegated-99');

    final jarCookies = await loadCookieMap(yt.cookieJar, kYoutubeOrigin);
    expect(jarCookies['SAPISID'], 'test-sapisid');
    expect(jarCookies['SIDCC'], 'fresh-sidcc');
  });

  test('attaches Music _u SAPISIDHASH on music.youtube.com youtubei', () async {
    late http.BaseRequest sent;
    final inner = MockClient((req) async {
      sent = req;
      return http.Response('{}', 200, request: req);
    });

    final client = YtmSessionHttpClient(inner: inner, ytmusic: yt);
    final req = http.Request(
      'POST',
      Uri.parse(
        'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false',
      ),
    )..headers['X-Youtube-Client-Name'] = '67';

    await client.send(req);

    expect(sent.headers['Authorization'], startsWith('SAPISIDHASH '));
    expect(sent.headers['Authorization'], contains('_u'));
    expect(sent.headers['X-Youtube-Bootstrap-Logged-In'], 'true');
    expect(sent.headers['X-Goog-AuthUser'], '1');
    expect(sent.headers['X-Goog-PageId'], 'delegated-99');
  });

  test('YoutubeClientPolicy classifies cookieless clients and maps UAs', () {
    expect(YoutubeClientPolicy.isCookielessClient('VISIONOS'), isTrue);
    expect(YoutubeClientPolicy.isCookielessClient('ANDROID_VR'), isTrue);
    expect(YoutubeClientPolicy.isCookielessClient('ANDROID_MUSIC'), isTrue);
    expect(YoutubeClientPolicy.isCookielessClient('TVHTML5'), isFalse);

    final vrUri = Uri.parse(
      'https://rr1---sn.googlevideo.com/videoplayback?c=ANDROID_VR',
    );
    expect(YoutubeClientPolicy.shouldAttachCookiesForStreamUrl(vrUri), isFalse);
    expect(
      YoutubeClientPolicy.userAgentForStreamUrl(vrUri),
      (YoutubeApiClient.androidVr.payload['context']
          as Map)['client']['userAgent'],
    );
    expect(
      YoutubeClientPolicy.userAgentForStreamUrl(
        Uri.parse('https://rr1---sn.googlevideo.com/videoplayback?c=TVHTML5'),
      ),
      (YoutubeApiClient.tv.payload['context'] as Map)['client']['userAgent'],
    );
  });

  test(
    'notifies session cookie rotation and handles LOGIN_INFO revocation',
    () async {
      var rotationCount = 0;
      var revokedCount = 0;
      yt.onSessionCookiesChanged = () => rotationCount++;
      yt.onSessionRevoked = () async {
        revokedCount++;
      };
      addTearDown(() {
        yt.onSessionCookiesChanged = null;
        yt.onSessionRevoked = null;
      });

      var step = 0;
      final inner = MockClient((req) async {
        step++;
        return http.Response(
          '{}',
          200,
          headers: {
            'set-cookie': step == 1
                ? 'SIDCC=rotated-1; Path=/; Domain=.youtube.com; Secure'
                : 'LOGIN_INFO=; Max-Age=0; Path=/; Domain=.youtube.com',
          },
          request: req,
        );
      });

      final client = YtmSessionHttpClient(inner: inner, ytmusic: yt);
      await client.send(
        http.Request(
          'POST',
          Uri.parse('https://www.youtube.com/youtubei/v1/player'),
        )..headers['X-Youtube-Client-Name'] = 'TVHTML5',
      );
      expect(rotationCount, 1);
      expect(revokedCount, 0);

      await client.send(
        http.Request(
          'POST',
          Uri.parse('https://www.youtube.com/youtubei/v1/player'),
        )..headers['X-Youtube-Client-Name'] = 'TVHTML5',
      );
      expect(revokedCount, 1);
      expect(await isSignedIn(yt.cookieJar), isFalse);
      expect(yt.config['USER_SESSION_ID'], isEmpty);
    },
  );
}
