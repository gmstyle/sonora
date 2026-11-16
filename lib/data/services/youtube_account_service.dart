import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart' as ytm;
import 'package:flutter/foundation.dart';

import '../datasources/remote/stream_datasource.dart';
import '../datasources/remote/ytmusic_datasource.dart';
import 'youtube_session_store.dart';

/// Applies, persists, and clears the shared YouTube Music session.
class YoutubeAccountService {
  YoutubeAccountService({
    required this.store,
    required this.ytmusic,
    required this.streams,
    required this.gl,
    required this.hl,
  });

  final YoutubeSessionStore store;
  final YtmusicDatasource ytmusic;
  final StreamDatasource streams;
  final String Function() gl;
  final String Function() hl;

  ytm.YTMusic get _client => ytmusic.client;

  Future<bool> isSignedIn() => ytm.isSignedIn(_client.cookieJar);

  /// Loads the on-disk session into the jar before the first Innertube call.
  Future<void> restore() async {
    await store.loadInto(_client);
  }

  /// Writes [cookies] into the jar, re-scrapes config, and persists.
  ///
  /// [account] is an optional card captured from the login WebView when
  /// `account/account_menu` is not yet available to the Dart HTTP client.
  Future<void> applyCookies(
    Iterable<Cookie> cookies, {
    ytm.AccountInfo? account,
  }) async {
    final filtered = ytm.filterYoutubeSessionCookies(cookies);
    await ytm.applyAuthCookies(_client.cookieJar, filtered);
    await _refreshClients();
    await store.saveFrom(_client);
    if (account != null) {
      await store.saveAccount(account);
    }
  }

  /// Same as [applyCookies] from a `name=value; …` header.
  Future<void> applyCookieHeader(String header) async {
    await applyCookies(ytm.parseCookieHeader(header));
  }

  Future<ytm.AccountInfo?> cachedAccount() => store.loadAccount();

  Future<void> cacheAccount(ytm.AccountInfo info) => store.saveAccount(info);

  Future<void> signOut() async {
    await ytm.clearAuthCookies(_client.cookieJar);
    await store.clear();
    await _refreshClients();
  }

  Future<void> _refreshClients() async {
    try {
      await ytmusic.reinitialize(gl: gl(), hl: hl());
    } catch (e) {
      debugPrint('YouTube session reinitialize failed: $e');
    }
    streams.clearUrlCache();
  }
}
