import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/remote/stream_datasource.dart';
import '../../data/datasources/remote/ytmusic_datasource.dart';
import '../../data/services/youtube_account_service.dart';
import '../../data/services/youtube_session_store.dart';
import 'connectivity_provider.dart';
import 'settings_provider.dart';
import 'stream_datasource_provider.dart';
import 'ytmusic_provider.dart';

final youtubeSessionStoreProvider = Provider<YoutubeSessionStore>((ref) {
  throw UnimplementedError('youtubeSessionStoreProvider must be overridden');
});

final youtubeAccountServiceProvider = Provider<YoutubeAccountService>((ref) {
  return YoutubeAccountService(
    store: ref.watch(youtubeSessionStoreProvider),
    ytmusic: ref.watch(ytmusicDatasourceProvider),
    streams: ref.watch(streamDatasourceProvider),
    gl: () => ref.read(settingsProvider).gl,
    hl: () => ref.read(settingsProvider).hl,
  );
});

class YoutubeAccountState {
  const YoutubeAccountState({
    required this.signedIn,
    this.sessionGeneration = 0,
  });

  final bool signedIn;

  /// Bumped on each cookie apply so [youtubeAccountInfoProvider] re-fetches
  /// without `ref.invalidate` from this notifier (that circular-depends).
  final int sessionGeneration;

  YoutubeAccountState copyWith({bool? signedIn, int? sessionGeneration}) =>
      YoutubeAccountState(
        signedIn: signedIn ?? this.signedIn,
        sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      );
}

class YoutubeAccountNotifier extends Notifier<YoutubeAccountState> {
  @override
  YoutubeAccountState build() {
    Future.microtask(_refresh);
    return const YoutubeAccountState(signedIn: false);
  }

  YoutubeAccountService get _service => ref.read(youtubeAccountServiceProvider);

  Future<void> _refresh() async {
    final signedIn = await _service.isSignedIn();
    state = state.copyWith(signedIn: signedIn);
  }

  Future<void> applyCookies(
    Iterable<Cookie> cookies, {
    AccountInfo? account,
  }) async {
    await _service.applyCookies(cookies, account: account);
    state = YoutubeAccountState(
      signedIn: true,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }

  Future<void> applyCookieMap(
    Map<String, String> cookies, {
    AccountInfo? account,
  }) async {
    final list = <Cookie>[];
    for (final e in cookies.entries) {
      try {
        list.add(Cookie(e.key, e.value)..domain = '.youtube.com');
      } catch (_) {}
    }
    await applyCookies(list, account: account);
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = YoutubeAccountState(
      signedIn: false,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }

  Future<void> refresh() => _refresh();
}

final youtubeAccountProvider =
    NotifierProvider<YoutubeAccountNotifier, YoutubeAccountState>(
      YoutubeAccountNotifier.new,
    );

/// Profile card: live `account_menu` when possible, else the login-time cache.
final youtubeAccountInfoProvider = FutureProvider<AccountInfo?>((ref) async {
  final account = ref.watch(youtubeAccountProvider);
  if (!account.signedIn) return null;
  // Depend on generation so a fresh login re-runs without notifier.invalidate.
  final _ = account.sessionGeneration;
  final service = ref.read(youtubeAccountServiceProvider);
  if (!ref.watch(isOfflineProvider)) {
    try {
      final live = await ref.read(ytmusicDatasourceProvider).getAccountInfo();
      if (live != null) {
        await service.cacheAccount(live);
        return live;
      }
    } catch (_) {
      // Fall through to the cached card from the login WebView.
    }
  }
  return service.cachedAccount();
});

/// Creates the session store under the app support directory.
Future<YoutubeSessionStore> createYoutubeSessionStore() async {
  final dir = await getApplicationSupportDirectory();
  return YoutubeSessionStore.inDirectory(dir.path);
}

/// Restores the jar before Innertube init (call from [main] / CLI).
Future<void> restoreYoutubeSession({
  required YoutubeSessionStore store,
  required YtmusicDatasource ytmusic,
  StreamDatasource? streams,
}) async {
  final service = YoutubeAccountService(
    store: store,
    ytmusic: ytmusic,
    streams: streams ?? StreamDatasource(),
    gl: () => 'US',
    hl: () => 'en',
  );
  await service.restore();
}
