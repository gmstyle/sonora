import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
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
import 'domain/usecases/player/play_video_id_use_case.dart';
import 'l10n/app_localizations.dart';
import 'presentation/app/router.dart';
import 'presentation/features/player/audio_handler.dart';
import 'presentation/providers/database_provider.dart';
import 'presentation/providers/library_repository_provider.dart';
import 'presentation/providers/music_repository_provider.dart';
import 'presentation/providers/metadata_sync_service.dart';
import 'presentation/providers/play_video_id_use_case_provider.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/cast_provider.dart';
import 'presentation/providers/stream_datasource_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/update_notifier.dart';
import 'presentation/providers/ytmusic_provider.dart';

LinuxTrayService? _trayService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const linuxSettings = LinuxInitializationSettings(
    defaultActionName: 'Open Sonora',
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    ),
  );

  await YTMusic().initialize();

  final prefs = await SharedPreferences.getInstance();

  // Build shared instances early so SonoraAudioHandler (which runs inside the
  // background audio service) has access to them before the Flutter widget
  // tree is rendered.
  final db = createAppDatabase();
  final ytmusicDs = YtmusicDatasource();
  final streamDs = StreamDatasource();
  final libraryRepo = LibraryRepositoryImpl(
    LibraryDao(db),
    PlaylistsDao(db),
    DownloadsDao(db),
    HistoryDao(db),
  );
  final musicRepo = MusicRepositoryImpl(ytmusicDs, streamDs);
  final playVideoIdUseCase = PlayVideoIdUseCase(musicRepo, libraryRepo);

  final queueRepo = QueueRepositoryImpl(db);

  final handler = SonoraAudioHandler(
    musicRepo: musicRepo,
    libraryRepo: libraryRepo,
    playVideoIdUseCase: playVideoIdUseCase,
    prefs: prefs,
    queueRepo: queueRepo,
  );

  if (isAndroid || isLinux) {
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sonora.music.channel',
        androidNotificationChannelName: 'Sonora',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        artDownscaleWidth: 256,
        artDownscaleHeight: 256,
        androidBrowsableRootExtras: {
          'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
          'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 2,
          'android.media.browse.SEARCH_SUPPORTED': true,
        },
        fastForwardInterval: Duration(seconds: 10),
        rewindInterval: Duration(seconds: 10),
      ),
    );
  }

  if (isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Sonora',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    _trayService = LinuxTrayService();
    await _trayService!.init();
    LinuxTrayService.setAudioHandler(handler);
  }

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
      ],
      child: const SonoraApp(),
    ),
  );
}

class SonoraApp extends ConsumerStatefulWidget {
  const SonoraApp({super.key});

  @override
  ConsumerState<SonoraApp> createState() => _SonoraAppState();
}

class _SonoraAppState extends ConsumerState<SonoraApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (isLinux) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _requestNotificationPermission();
    });
  }

  @override
  void dispose() {
    if (isLinux) windowManager.removeListener(this);
    super.dispose();
  }

  // Intercept the window close button: hide to tray instead of quitting.
  @override
  void onWindowClose() async {
    await windowManager.hide();
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
      builder: (_) => const _StartupUpdateDialog(),
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

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Link AudioHandler with Casting
    final audioHandler = ref.watch(audioHandlerProvider);
    ref.listen(castStateProvider, (previous, next) {
      next.whenData((state) {
        audioHandler.updateCastState(state, ref.read(castServiceProvider));
      });
    });

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightTheme = ref.watch(lightThemeProvider(lightDynamic));
        final darkTheme = ref.watch(darkThemeProvider(darkDynamic));

        return MaterialApp.router(
          title: AppLocalizations.of(context)?.appTitle ?? 'Sonora',
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
        );
      },
    );
  }
}

class _StartupUpdateDialog extends ConsumerStatefulWidget {
  const _StartupUpdateDialog();

  @override
  ConsumerState<_StartupUpdateDialog> createState() =>
      _StartupUpdateDialogState();
}

class _StartupUpdateDialogState extends ConsumerState<_StartupUpdateDialog> {
  String _localVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _localVersion = 'v${info.version}+${info.buildNumber}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(updateProvider.notifier);

    return PopScope(
      canPop:
          state.status != UpdateStatus.checking &&
          state.status != UpdateStatus.downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) notifier.reset();
      },
      child: AlertDialog(
        title: Text(_title(state, l10n)),
        content: _content(state, l10n),
        actions: _actions(state, l10n, notifier),
      ),
    );
  }

  String _title(UpdateState state, AppLocalizations l10n) {
    switch (state.status) {
      case UpdateStatus.downloading:
        return l10n.downloadingUpdate;
      case UpdateStatus.downloadComplete:
        return l10n.updateAvailable;
      default:
        return l10n.updateAvailable;
    }
  }

  Widget _content(UpdateState state, AppLocalizations l10n) {
    switch (state.status) {
      case UpdateStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 12),
            Text('${(state.progress * 100).toStringAsFixed(0)}%'),
          ],
        );

      case UpdateStatus.downloadComplete:
        return Text(l10n.downloadComplete);

      default:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_localVersion.isNotEmpty)
                Text(l10n.currentVersion(_localVersion)),
              Text(l10n.latestVersion(state.result?.latestVersion ?? '')),
              if (state.result?.changelog.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  state.result!.changelog,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
    }
  }

  List<Widget> _actions(
    UpdateState state,
    AppLocalizations l10n,
    UpdateNotifier notifier,
  ) {
    switch (state.status) {
      case UpdateStatus.downloading:
        return [];

      case UpdateStatus.downloadComplete:
        return [
          TextButton(
            onPressed: () {
              notifier.reset();
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
          FilledButton.icon(
            onPressed: () => notifier.installApk(),
            icon: const Icon(LucideIcons.smartphone),
            label: Text(l10n.installUpdate),
          ),
        ];

      default:
        return [
          TextButton(
            onPressed: () {
              notifier.reset();
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
          if (isAndroid)
            FilledButton.icon(
              onPressed: () => notifier.downloadAndInstall(),
              icon: const Icon(LucideIcons.download),
              label: Text(l10n.downloadUpdate),
            )
          else
            FilledButton.icon(
              onPressed: () {
                notifier.reset();
                Navigator.pop(context);
                launchUrl(
                  Uri.parse('$kGitHubRepoUrl/releases/latest'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(LucideIcons.externalLink),
              label: Text(l10n.downloadUpdate),
            ),
        ];
    }
  }
}
