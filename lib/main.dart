import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'core/utils/platform_utils.dart';
import 'l10n/app_localizations.dart';
import 'presentation/features/player/audio_handler.dart';
import 'presentation/providers/player_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  JustAudioMediaKit.ensureInitialized();

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
      overrides: [audioHandlerProvider.overrideWithValue(handler)],
      child: const SonoraApp(),
    ),
  );
}

class SonoraApp extends StatelessWidget {
  const SonoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonora',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Text(
          l10n.helloSonora,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
