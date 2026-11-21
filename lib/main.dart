import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/link/sonora_link_handler.dart';
import 'core/utils/android_tv.dart';
import 'core/utils/linux_single_instance.dart';
import 'core/utils/notification_utils.dart';
import 'core/utils/platform_utils.dart';
import 'core/utils/linux_tray_service.dart';
import 'data/datasources/local/database_connection.dart';
import 'data/datasources/local/daos/downloads_dao.dart';
import 'data/datasources/local/daos/history_dao.dart';
import 'data/datasources/local/daos/library_dao.dart';
import 'data/datasources/local/daos/playlists_dao.dart';
import 'data/datasources/remote/stream_datasource.dart';
import 'data/datasources/remote/ytmusic_datasource.dart';
import 'data/repositories/library_repository_impl.dart';
import 'data/repositories/music_repository_impl.dart';
import 'data/repositories/queue_repository_impl.dart';
import 'data/services/local_audio_proxy_server.dart';
import 'data/services/sync_service.dart';
import 'data/services/youtube_session_store.dart';
import 'domain/models/media_quality.dart';
import 'domain/usecases/download/cleanup_incomplete_downloads_use_case.dart';
import 'domain/usecases/player/play_video_id_use_case.dart';
import 'l10n/app_localizations.dart';
import 'presentation/app/router.dart';
import 'presentation/features/player/audio_handler.dart';
import 'presentation/features/tv/tv_metrics.dart';
import 'presentation/providers/android_tv_provider.dart';
import 'presentation/providers/database_provider.dart';
import 'presentation/providers/download_notification_service.dart';
import 'presentation/providers/download_provider.dart';
import 'presentation/providers/library_repository_provider.dart';
import 'presentation/providers/linux_update_providers.dart';
import 'presentation/providers/music_repository_provider.dart';
import 'presentation/providers/metadata_sync_service.dart';
import 'presentation/providers/play_video_id_use_case_provider.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/cast_provider.dart';
import 'presentation/providers/action_feedback_provider.dart';
import 'presentation/providers/stream_datasource_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/update_notifier.dart';
import 'presentation/providers/youtube_account_provider.dart';
import 'presentation/providers/ytmusic_provider.dart';
import 'presentation/shared/widgets/update_dialog.dart';

import 'package:path_provider/path_provider.dart';

import 'package:go_router/go_router.dart';

/// Cold-start `sonora://` URI from Linux argv (set before [runApp]).
String? _linuxColdStartUri;

LinuxTrayService? _trayService;
Window? _linuxWindow;
ListenerId? _linuxWindowListenerId;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isLinux) {
    _linuxColdStartUri = extractSonoraUriFromArgs(Platform.executableArguments);
    // Secondary instances forward the URI and exit(0) — never returns.
    await LinuxSingleInstance.ensurePrimary(onSecondaryUri: _linuxColdStartUri);
    JustAudioMediaKit.ensureInitialized(windows: false);
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const linuxSettings = LinuxInitializationSettings(
    defaultActionName: 'Open Sonora',
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    ),
    onDidReceiveNotificationResponse: handleDownloadNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
        handleDownloadNotificationResponseBackground,
  );

  final prefs = await SharedPreferences.getInstance();
  await migrateLegacySettingsPrefs(prefs);

  // Build shared instances early so SonoraAudioHandler (which runs inside the
  // background audio service) has access to them before the Flutter widget
  // tree is rendered.
  final db = createAppDatabase();
  final supportDir = await getApplicationSupportDirectory();
  final youtubeSessionStore = YoutubeSessionStore.inDirectory(supportDir.path);
  final ytmusicDs = YtmusicDatasource();
  ytmusicDs.client.onSessionCookiesChanged = () =>
      youtubeSessionStore.scheduleSaveFrom(ytmusicDs.client);
  // Restore auth cookies before the first Innertube scrape.
  await youtubeSessionStore.loadInto(ytmusicDs.client);
  // First init wins. A bare YTMusic().initialize() would lock HL to the
  // English homepage and ignore the saved country and content language.
  await ytmusicDs.initialize(
    gl: prefs.getString(kGlKey) ?? 'US',
    hl: prefs.getString(kHlKey) ?? 'en',
  );
  // Persist SID/LOGIN_INFO rotation from the authenticated homepage scrape.
  await youtubeSessionStore.saveFrom(ytmusicDs.client);
  final streamDs = StreamDatasource(
    getDefaultAudioQuality: () =>
        MediaQuality.fromStorage(readStreamAudioQualityPref(prefs)),
  );

  final proxyServer = LocalAudioProxyServer(
    streamDatasource: streamDs,
    isForcedOffline: () => prefs.getBool(kOfflineModeKey) ?? false,
  );
  await proxyServer.start();

  final libraryRepo = LibraryRepositoryImpl(
    LibraryDao(db),
    PlaylistsDao(db),
    DownloadsDao(db),
    HistoryDao(db),
  );

  // Remove downloads interrupted by a previous session (kill/crash) together
  // with their partial files, before any screen can display them.
  await CleanupIncompleteDownloadsUseCase(libraryRepo).execute();

  final musicRepo = MusicRepositoryImpl(ytmusicDs, streamDs);
  final playVideoIdUseCase = PlayVideoIdUseCase(
    musicRepo,
    libraryRepo,
    () => prefs.getBool(kOfflineModeKey) ?? false,
  );

  final queueRepo = QueueRepositoryImpl(db);

  final handler = SonoraAudioHandler(
    musicRepo: musicRepo,
    libraryRepo: libraryRepo,
    playVideoIdUseCase: playVideoIdUseCase,
    streamDatasource: streamDs,
    prefs: prefs,
    queueRepo: queueRepo,
    proxyServer: proxyServer,
  );

  if (isAndroid || isLinux) {
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sonora.music.channel',
        androidNotificationChannelName: 'Sonora',
        androidNotificationIcon: 'drawable/ic_notification',
        androidStopForegroundOnPause: false,
        artDownscaleWidth: 256,
        artDownscaleHeight: 256,
        androidBrowsableRootExtras: {
          'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
          'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
          'android.media.browse.SEARCH_SUPPORTED': true,
        },
      ),
    );
  }

  if (isLinux) {
    final window = WindowManager.instance.getCurrent()!;
    _linuxWindow = window;
    window.setSize(const Size(1200, 800).toNative(), false);
    window.minimumSize = const Size(800, 600).toNative();
    window.center();
    window.backgroundColor = Colors.transparent.toNative();
    window.isVisibleInTaskbar = true;
    window.titleBarStyle = TitleBarStyle.normal;
    window.title = 'Sonora';
    _linuxWindowListenerId = window.addListener((event) {
      if (event case WindowCloseRequestedEvent(:final request)) {
        if (!LinuxTrayService.isQuitRequested) {
          request.cancel();
          window.hide();
        }
      }
    });
    window.show();
    window.focus();

    _trayService = LinuxTrayService();
    await _trayService!.init();
    LinuxTrayService.setAudioHandler(handler);
  }

  final isAndroidTv = await AndroidTv.isAndroidTv();
  await AndroidTv.debugLogDetection();
  debugPrint('[AndroidTv] isAndroidTv=$isAndroidTv');

  // Sonora's own license is not part of the generated NOTICES asset.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(const [
      'Sonora',
    ], '$text\n\nSource code: $kGitHubRepoUrl');
  });

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        ytmusicDatasourceProvider.overrideWithValue(ytmusicDs),
        streamDatasourceProvider.overrideWithValue(streamDs),
        libraryRepositoryProvider.overrideWithValue(libraryRepo),
        musicRepositoryProvider.overrideWithValue(musicRepo),
        playVideoIdUseCaseProvider.overrideWithValue(playVideoIdUseCase),
        youtubeSessionStoreProvider.overrideWithValue(youtubeSessionStore),
        isAndroidTvProvider.overrideWithValue(isAndroidTv),
        if (isLinux)
          linuxAppShutdownProvider.overrideWithValue(
            () => _shutdownLinuxForRestart(
              handler: handler,
              proxyServer: proxyServer,
              youtubeSessionStore: youtubeSessionStore,
              ytmusicDs: ytmusicDs,
              db: db,
            ),
          ),
      ],
      child: const SonoraApp(),
    ),
  );
}

Future<void> _shutdownLinuxForRestart({
  required SonoraAudioHandler handler,
  required LocalAudioProxyServer proxyServer,
  required YoutubeSessionStore youtubeSessionStore,
  required YtmusicDatasource ytmusicDs,
  required AppDatabase db,
}) async {
  Future<void> runStep(String label, FutureOr<void> Function() action) async {
    try {
      await Future<void>.sync(action)
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Linux restart shutdown ($label) failed: $e');
    }
  }

  await runStep('audio', handler.stop);
  await runStep('proxy', proxyServer.stop);
  await runStep(
    'session',
    () => youtubeSessionStore.saveFrom(ytmusicDs.client),
  );
  await runStep('db', db.close);
  await runStep('single-instance', LinuxSingleInstance.dispose);
}

class SonoraApp extends ConsumerStatefulWidget {
  const SonoraApp({super.key});

  @override
  ConsumerState<SonoraApp> createState() => _SonoraAppState();
}

class _SonoraAppState extends ConsumerState<SonoraApp> {
  late final SonoraLinkHandler _linkHandler;
  StreamSubscription<Uri>? _appLinksSub;
  StreamSubscription<String>? _linuxUriSub;

  @override
  void initState() {
    super.initState();
    _linkHandler = SonoraLinkHandler(ref);
    downloadNotificationActionHandler = _onDownloadNotificationAction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _requestNotificationPermission();
      _initDeepLinks();
    });
  }

  @override
  void dispose() {
    if (downloadNotificationActionHandler == _onDownloadNotificationAction) {
      downloadNotificationActionHandler = null;
    }
    unawaited(_appLinksSub?.cancel());
    unawaited(_linuxUriSub?.cancel());
    if (isLinux && _linuxWindowListenerId != null) {
      _linuxWindow?.removeListener(_linuxWindowListenerId!);
    }
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      // Subscribe before handling cold-start so a near-simultaneous xdg-open
      // (GtkApplication remote → Unix socket) is not dropped.
      if (isLinux) {
        _linuxUriSub = LinuxSingleInstance.uriStream.listen((uri) {
          unawaited(_onIncomingLinuxUri(uri));
        });
      }

      if (isLinux && _linuxColdStartUri != null) {
        debugPrint('Deep link cold-start: $_linuxColdStartUri');
        await _linkHandler.handleRaw(_linuxColdStartUri!);
      }

      if (isAndroid) {
        // uriLinkStream includes the cold-start link; do not also call
        // getInitialLink() or the same URI is handled twice.
        _appLinksSub = AppLinks().uriLinkStream.listen((uri) {
          unawaited(_onIncomingLink(uri.toString()));
        });
      }

      await _linkHandler.flushPending();
      // Router may still be mounting on the first frame; retry once.
      if (rootNavigatorKey.currentContext == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_linkHandler.flushPending());
        });
      }
    } catch (e) {
      debugPrint('Deep link init failed: $e');
    }
  }

  Future<void> _onIncomingLink(String raw) async {
    await _linkHandler.handleRaw(raw);
  }

  Future<void> _onIncomingLinuxUri(String uri) async {
    try {
      LinuxTrayService.presentWindow();
    } catch (e) {
      debugPrint('Failed to show/focus window for deep link: $e');
    }
    if (uri.isNotEmpty) {
      await _linkHandler.handleRaw(uri);
    }
  }

  void _onDownloadNotificationAction(String actionId) {
    if (actionId == kDownloadCancelAllActionId) {
      ref.read(activeDownloadsProvider.notifier).cancelAll();
      return;
    }
    if (actionId == kDownloadOpenActionId) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) {
        ctx.go('/downloads');
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (kDebugMode) return;

    try {
      final settings = ref.read(settingsProvider);
      if (!settings.checkUpdatesOnStartup) return;

      final prefs = ref.read(sharedPreferencesProvider);
      final lastCheck = prefs.getInt(kLastUpdateCheckTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < const Duration(hours: 24).inMilliseconds) return;

      final notifier = ref.read(updateProvider.notifier);
      await notifier.checkForUpdate();

      if (!mounted) return;

      final state = ref.read(updateProvider);
      if (state.status == UpdateStatus.updateAvailable && mounted) {
        _showUpdateDialog();
      }

      if (state.status == UpdateStatus.updateAvailable ||
          state.status == UpdateStatus.noUpdateAvailable) {
        await prefs.setInt(kLastUpdateCheckTimeKey, now);
      }
    } catch (e) {
      debugPrint('Startup update check failed: $e');
    }
  }

  void _showUpdateDialog() {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      debugPrint(
        'Could not show update dialog: rootNavigatorKey.currentContext is null',
      );
      return;
    }
    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (_) => const UpdateDialog(),
    );
  }

  void _showIncomingPairingRequestPinDialog(
    BuildContext context,
    WidgetRef ref,
    PairingRequest request,
  ) {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    final l10n = AppLocalizations.of(navContext)!;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (context) {
        return _PairingPinDialog(
          request: request,
          titleText: l10n.devicePairingTitle,
          messageText: l10n.devicePairingDesc(request.clientName),
          cancelText: l10n.cancel,
          onCancel: () {
            ref
                .read(syncNotifierProvider.notifier)
                .respondToIncomingRequest(false);
          },
          pairingSuccessText: l10n.pairingSuccess,
          navContext: navContext,
        );
      },
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (!isAndroid) return;
    try {
      await Permission.notification.request();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(metadataSyncServiceProvider);

    ref.listen(syncNotifierProvider.select((s) => s.activeIncomingRequest), (
      previous,
      next,
    ) {
      if (next != null && previous != next) {
        _showIncomingPairingRequestPinDialog(context, ref, next);
      }
    });

    ref.listen(playerStateProvider, (prev, next) {
      if (isLinux) {
        if (prev?.isPlaying != next.isPlaying ||
            prev?.currentSong?.id != next.currentSong?.id ||
            prev?.shuffleMode != next.shuffleMode ||
            prev?.repeatMode != next.repeatMode) {
          LinuxTrayService.instance?.updatePlaybackState(
            next.isPlaying,
            title: next.currentSong?.title,
            artist: next.currentSong?.artist,
            shuffleMode: next.shuffleMode,
            repeatMode: next.repeatMode,
          );
        }
      }
    });

    // Keep queue proxy URLs in sync with stream quality prefs.
    ref.listen(settingsProvider.select((s) => s.streamAudioQuality), (
      previous,
      next,
    ) {
      ref
          .read(audioHandlerProvider)
          .updateStreamPrefs(streamAudioQuality: next);
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Link AudioHandler with Casting
    final audioHandler = ref.watch(audioHandlerProvider);
    ref.listen(castStateProvider, (previous, next) {
      next.whenData((state) {
        audioHandler.updateCastState(state, ref.read(castServiceProvider));
      });
    });

    final isTv = ref.watch(isAndroidTvProvider);
    final lightTheme = ref.watch(lightThemeProvider);
    final rawDarkTheme = ref.watch(darkThemeProvider);
    final darkTheme = isTv ? TvTheme.apply(rawDarkTheme) : rawDarkTheme;

    return MaterialApp.router(
      title: AppLocalizations.of(context)?.appTitle ?? 'Sonora',
      routerConfig: router,
      // gen-l10n still lists legacy flutter_localizations Material/Cupertino
      // delegates; use material_ui's bundle instead.
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: isTv ? darkTheme : lightTheme,
      darkTheme: darkTheme,
      themeMode: isTv ? ThemeMode.dark : themeMode,
    );
  }
}

class _PairingPinDialog extends StatefulWidget {
  final PairingRequest request;
  final String titleText;
  final String messageText;
  final String cancelText;
  final VoidCallback onCancel;
  final String pairingSuccessText;
  final BuildContext navContext;

  const _PairingPinDialog({
    required this.request,
    required this.titleText,
    required this.messageText,
    required this.cancelText,
    required this.onCancel,
    required this.pairingSuccessText,
    required this.navContext,
  });

  @override
  State<_PairingPinDialog> createState() => _PairingPinDialogState();
}

class _PairingPinDialogState extends State<_PairingPinDialog> {
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });

    final messengerContainer = ProviderScope.containerOf(widget.navContext);

    widget.request.completer.future.then((paired) {
      if (mounted) {
        Navigator.of(context).pop();
        if (paired == true) {
          messengerContainer
              .read(actionFeedbackProvider.notifier)
              .report(widget.pairingSuccessText);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final expireText = isIt
        ? 'Scade in $_secondsRemaining secondi'
        : 'Expires in $_secondsRemaining seconds';

    return AlertDialog(
      title: Text(widget.titleText),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.messageText, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.request.pin,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _secondsRemaining / 60.0,
            color: _secondsRemaining < 15
                ? Colors.red
                : theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          Text(
            expireText,
            style: TextStyle(
              color: _secondsRemaining < 15 ? Colors.red : Colors.grey,
              fontWeight: _secondsRemaining < 15 ? FontWeight.bold : null,
              fontSize: 13,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop();
            widget.onCancel();
          },
          child: Text(widget.cancelText),
        ),
      ],
    );
  }
}
