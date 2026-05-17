import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/utils/notification_utils.dart';
import 'core/utils/platform_utils.dart';
import 'l10n/app_localizations.dart';
import 'presentation/app/router.dart';
import 'presentation/features/player/audio_handler.dart';
import 'presentation/providers/check_for_updates_use_case_provider.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isLinux) JustAudioMediaKit.ensureInitialized();

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
  final handler = SonoraAudioHandler();

  if (isAndroid) {
    await AudioService.init(
      builder: () => handler,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.sonora.music.channel',
        androidNotificationChannelName: 'Sonora',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        sharedPreferencesProvider.overrideWithValue(prefs),
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

class _SonoraAppState extends ConsumerState<SonoraApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
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
        currentVersion: 'v${info.version}',
        lastCheckEpochMillis: null,
      );

      if (result.isNewer && mounted) {
        await flutterLocalNotificationsPlugin.show(
          id: 0,
          title: 'Update Available',
          body: 'Sonora ${result.latestVersion} is available'
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
