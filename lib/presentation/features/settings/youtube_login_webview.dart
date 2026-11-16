import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../data/services/webview_cookie_reader.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/youtube_account_provider.dart';

/// Google sign-in WebView.
///
/// Continues into Music (not m.youtube.com) so the session and account card
/// settle on the same origin Dart will call. After SAPISID is present and the
/// browser has left Google accounts, waits on Music, fetches `account_menu`
/// from the page with SAPISIDHASH, then hands cookies + card to Dart.
class YoutubeLoginWebView extends ConsumerStatefulWidget {
  const YoutubeLoginWebView({super.key, this.forCaptcha = false});

  final bool forCaptcha;

  /// Land on Music after Google — account_menu and LOGIN_INFO settle here.
  static const loginUrl =
      'https://accounts.google.com/Logout?continue=https://music.youtube.com/';

  /// Chrome on Android without the WebView `; wv)` token Google flags.
  static const mobileChromeUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

  static Future<bool?> open(BuildContext context, {bool forCaptcha = false}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => YoutubeLoginWebView(forCaptcha: forCaptcha),
      ),
    );
  }

  @override
  ConsumerState<YoutubeLoginWebView> createState() =>
      _YoutubeLoginWebViewState();
}

class _YoutubeLoginWebViewState extends ConsumerState<YoutubeLoginWebView> {
  late final WebViewController _controller;
  var _finishing = false;
  var _progress = 0;
  var _ready = false;
  var _openedMusic = false;
  DateTime? _musicSince;
  Completer<String>? _accountJs;
  Timer? _poll;

  static const _musicWait = Duration(seconds: 15);
  static const _accountChannel = 'SonoraYtAccount';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_prepareAndStart());
    _poll = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_checkCookies()),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _prepareAndStart() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setUserAgent(YoutubeLoginWebView.mobileChromeUa);
    await _controller.addJavaScriptChannel(
      _accountChannel,
      onMessageReceived: (message) {
        final pending = _accountJs;
        if (pending != null && !pending.isCompleted) {
          pending.complete(message.message);
        }
      },
    );
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) => unawaited(_checkCookies()),
        onUrlChange: (_) => unawaited(_checkCookies()),
      ),
    );

    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
      final cookieManager = WebViewCookieManager();
      if (cookieManager.platform is AndroidWebViewCookieManager) {
        await (cookieManager.platform as AndroidWebViewCookieManager)
            .setAcceptThirdPartyCookies(android, true);
      }
    }

    await WebViewCookieReader.clearCookies();
    await _controller.loadRequest(Uri.parse(YoutubeLoginWebView.loginUrl));
    if (mounted) setState(() => _ready = true);
  }

  bool _isGoogleHost(String host) {
    return host == 'accounts.google.com' ||
        (host.endsWith('.google.com') && host.contains('accounts'));
  }

  bool _isMusicUrl(String url) => url.contains('music.youtube.com');

  Future<Map<String, String>> _readCookies() async {
    final headers = await Future.wait([
      WebViewCookieReader.getCookie('https://www.youtube.com'),
      WebViewCookieReader.getCookie('https://music.youtube.com'),
      WebViewCookieReader.getCookie('https://m.youtube.com'),
      WebViewCookieReader.getCookie('https://accounts.google.com'),
    ]);
    final byName = <String, String>{};
    for (final header in headers) {
      if (header == null || header.isEmpty) continue;
      for (final c in parseCookieHeader(header)) {
        byName[c.name] = c.value;
      }
    }
    return byName;
  }

  Future<String> _ytcfgString(String key) async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        "(function(){try{var v=window.ytcfg&&ytcfg.get&&ytcfg.get('$key');"
        "return (v==null||v===undefined)?'':String(v);}catch(e){return '';}})()",
      );
      if (raw is! String) return '';
      var s = raw.trim();
      if (s.startsWith('"') && s.endsWith('"')) {
        s = s.substring(1, s.length - 1);
      }
      return s;
    } catch (_) {
      return '';
    }
  }

  String _accountMenuJs(String authorization) {
    final authLiteral = jsonEncode(authorization);
    return '''
(async function() {
  try {
    var cfg = window.ytcfg;
    if (!cfg || !cfg.get) {
      $_accountChannel.postMessage(JSON.stringify({error: 'no ytcfg'}));
      return;
    }
    var key = cfg.get('INNERTUBE_API_KEY') || '';
    var clientName = cfg.get('INNERTUBE_CLIENT_NAME') || 'WEB_REMIX';
    var clientVersion = cfg.get('INNERTUBE_CLIENT_VERSION') || '';
    var ctxClientName = cfg.get('INNERTUBE_CONTEXT_CLIENT_NAME') || '';
    var url = '/youtubei/v1/account/account_menu?prettyPrint=false';
    if (key) url += '&key=' + encodeURIComponent(key);
    var headers = {
      'Content-Type': 'application/json',
      'X-Goog-AuthUser': '0',
      'X-YouTube-Client-Name': String(ctxClientName),
      'X-YouTube-Client-Version': String(clientVersion)
    };
    var auth = $authLiteral;
    if (auth) headers['Authorization'] = auth;
    var res = await fetch(url, {
      method: 'POST',
      credentials: 'include',
      headers: headers,
      body: JSON.stringify({
        context: {
          client: {
            clientName: clientName,
            clientVersion: clientVersion,
            hl: cfg.get('HL') || 'en',
            gl: cfg.get('GL') || 'US'
          }
        }
      })
    });
    var json = await res.json();
    $_accountChannel.postMessage(JSON.stringify(json));
  } catch (e) {
    $_accountChannel.postMessage(JSON.stringify({error: String(e)}));
  }
})();
''';
  }

  Future<AccountInfo?> _fetchAccountFromPage(
    Map<String, String> cookies,
  ) async {
    final url = await _controller.currentUrl() ?? '';
    if (!_isMusicUrl(url)) {
      debugPrint('YT login: skip account fetch, url=$url');
      return null;
    }

    // Wait briefly for ytcfg on a fresh Music load.
    for (var i = 0; i < 8; i++) {
      final client = await _ytcfgString('INNERTUBE_CLIENT_VERSION');
      if (client.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final sessionId = await _ytcfgString('USER_SESSION_ID');
    final loggedIn = await _ytcfgString('LOGGED_IN');
    final auth = authorizationHeader(
      cookies,
      'https://music.youtube.com',
      userSessionId: sessionId.isEmpty ? null : sessionId,
    );
    debugPrint(
      'YT login: LOGGED_IN=$loggedIn USER_SESSION_ID=${sessionId.isNotEmpty} '
      'LOGIN_INFO=${jarHasLoginInfo(cookies)} auth=${auth != null}',
    );
    if (auth == null) return null;

    for (var attempt = 0; attempt < 3; attempt++) {
      final completer = Completer<String>();
      _accountJs = completer;
      try {
        await _controller.runJavaScript(_accountMenuJs(auth));
        final raw = await completer.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () => '',
        );
        if (raw.isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        if (decoded['error'] != null) {
          debugPrint('YT login: account_menu js error=${decoded['error']}');
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        final info = AccountInfo.fromAccountMenu(decoded);
        debugPrint(
          'YT login: account_menu '
          'header=${info != null} name=${info?.name} email=${info?.email}',
        );
        if (info != null) return info;
      } catch (e) {
        debugPrint('YT login: account fetch failed: $e');
      } finally {
        _accountJs = null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return null;
  }

  Future<void> _finish(Map<String, String> byName) async {
    if (_finishing || !mounted) return;
    _finishing = true;
    _poll?.cancel();

    final latest = await _readCookies();
    final merged = {...byName, ...latest};

    AccountInfo? account;
    try {
      account = await _fetchAccountFromPage(merged);
    } catch (e) {
      debugPrint('YT login: account capture error: $e');
    }

    final cookies = <Cookie>[];
    for (final e in merged.entries) {
      try {
        cookies.add(Cookie(e.key, e.value)..domain = '.youtube.com');
      } catch (_) {}
    }
    debugPrint(
      'YT login: finishing cookies=${cookies.length} '
      'LOGIN_INFO=${jarHasLoginInfo(merged)} account=${account?.email ?? account?.name}',
    );
    await ref
        .read(youtubeAccountProvider.notifier)
        .applyCookies(cookies, account: account);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _ensureMusic() async {
    if (_openedMusic) return;
    _openedMusic = true;
    _musicSince = DateTime.now();
    debugPrint('YT login: opening music.youtube.com');
    await _controller.loadRequest(Uri.parse('https://music.youtube.com/'));
  }

  Future<void> _checkCookies() async {
    if (_finishing || !mounted) return;
    try {
      final byName = await _readCookies();
      if (!jarHasAuth(byName)) return;
      final hasSapisid =
          (byName['SAPISID']?.isNotEmpty ?? false) ||
          (byName['__Secure-3PAPISID']?.isNotEmpty ?? false) ||
          (byName['__Secure-1PAPISID']?.isNotEmpty ?? false);
      if (!hasSapisid) return;

      final currentUrl = await _controller.currentUrl() ?? '';
      final host = Uri.tryParse(currentUrl)?.host ?? '';
      // Never navigate away while Google OAuth is still running.
      if (_isGoogleHost(host)) return;

      // Always settle on Music before closing — youtube.com alone is not enough
      // for account_menu / LOGIN_INFO in the Dart jar.
      if (!_isMusicUrl(currentUrl)) {
        await _ensureMusic();
        return;
      }

      _musicSince ??= DateTime.now();
      final waited = DateTime.now().difference(_musicSince!);
      final hasLoginInfo = jarHasLoginInfo(byName);
      // Prefer LOGIN_INFO, but do not hang forever on Music.
      if (!hasLoginInfo && waited < _musicWait) return;
      // Give ytcfg a moment even when LOGIN_INFO arrived early.
      if (waited < const Duration(seconds: 2)) return;

      await _finish(byName);
    } catch (e) {
      debugPrint('YT login: check failed: $e');
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountSignIn),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        children: [
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(value: _progress / 100),
          Expanded(
            child: _ready
                ? WebViewWidget(controller: _controller)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}
