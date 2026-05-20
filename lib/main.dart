import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/utils/notification_utils.dart';
import 'core/utils/platform_utils.dart';
import 'core/utils/linux_tray_service.dart';

import 'data/datasources/local/database.dart';
import 'data/datasources/local/daos/downloads_dao.dart';
import 'data/datasources/local/daos/history_dao.dart';
import 'data/datasources/local/daos/library_dao.dart';
import 'data/datasources/local/daos/playlists_dao.dart';
import 'data/datasources/remote/stream_datasource.dart';
import 'data/datasources/remote/ytmusic_datasource.dart';
import 'data/repositories/library_repository_impl.dart';
import 'data/repositories/music_repository_impl.dart';
import 'domain/usecases/player/play_video_id_use_case.dart';
import 'l10n/app_localizations.dart';
import 'presentation/app/router.dart';
import 'presentation/features/player/audio_handler.dart';
import 'presentation/providers/check_for_updates_use_case_provider.dart';
import 'presentation/providers/database_provider.dart';
import 'presentation/providers/library_repository_provider.dart';
import 'presentation/providers/music_repository_provider.dart';
import 'presentation/providers/play_video_id_use_case_provider.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/stream_datasource_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/ytmusic_provider.dart';

LinuxTrayService? _trayService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isLinux) JustAudioMediaKit.ensureInitialized();

  if (isAndroid) await Permission.notification.request();

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
  final db = AppDatabase.create();
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

  final handler = SonoraAudioHandler(
    musicRepo: musicRepo,
    libraryRepo: libraryRepo,
    playVideoIdUseCase: playVideoIdUseCase,
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
    try {
      final settings = ref.read(settingsProvider);
      if (!settings.checkUpdatesOnStartup) return;

      final prefs = ref.read(sharedPreferencesProvider);
      final lastCheck = prefs.getInt(kLastUpdateCheckTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < const Duration(hours: 24).inMilliseconds) return;

      await prefs.setInt(kLastUpdateCheckTimeKey, now);

      final useCase = ref.read(checkForUpdatesUseCaseProvider);
      final info = await PackageInfo.fromPlatform();
      final result = await useCase.execute(
        currentVersion: 'v${info.version}+${info.buildNumber}',
        lastCheckEpochMillis: null,
      );

      if (result.isNewer && mounted) {
        await flutterLocalNotificationsPlugin.show(
          id: 0,
          title: 'Update Available',
          body:
              'Sonora ${result.latestVersion} is available'
              ' (current: v${info.version})',
          notificationDetails: const NotificationDetails(
            linux: LinuxNotificationDetails(defaultActionName: 'Open Sonora'),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (isLinux) {
      ref.listen(playerStateProvider, (prev, next) {
        if (prev?.isPlaying != next.isPlaying ||
            prev?.currentSong?.id != next.currentSong?.id) {
          LinuxTrayService.instance?.updatePlaybackState(
            next.isPlaying,
            title: next.currentSong?.title,
            artist: next.currentSong?.artist,
          );
        }
      });
    }

    final router = ref.watch(routerProvider);
    final lightTheme = ref.watch(lightThemeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Sonora',
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
    );
  }
}
