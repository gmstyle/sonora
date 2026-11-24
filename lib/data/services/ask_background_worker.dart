import 'dart:ui' show DartPluginRegistrant, PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/constants/ai_constants.dart';
import '../../core/utils/notification_utils.dart';
import '../../domain/usecases/ai/evaluate_proactive_drops_use_case.dart';
import '../../presentation/providers/ask_notification_service.dart';
import '../../presentation/providers/settings_provider.dart';
import '../datasources/ai/deepseek_http_datasource.dart';
import '../datasources/local/daos/downloads_dao.dart';
import '../datasources/local/daos/history_dao.dart';
import '../datasources/local/daos/library_dao.dart';
import '../datasources/local/daos/playlists_dao.dart';
import '../datasources/local/database_connection.dart';
import '../datasources/remote/stream_datasource.dart';
import '../datasources/remote/ytmusic_datasource.dart';
import '../repositories/ask_storage_repository_impl.dart';
import '../repositories/deepseek_llm_repository_impl.dart';
import '../repositories/library_repository_impl.dart';
import '../repositories/music_repository_impl.dart';
import 'ask_background_scheduler.dart';
import 'prefs_ask_pulse_state_store.dart';

const Duration _kMinBackgroundEvalInterval = Duration(hours: 6);

@pragma('vm:entry-point')
void askBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (taskName != kAskProactiveWorkTask) return true;

    try {
      await runAskProactiveBackgroundCheck();
    } catch (e) {
      debugPrint('Ask background worker failed: $e');
    }
    return true;
  });
}

Future<void> runAskProactiveBackgroundCheck() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final askDropsEnabled = prefs.getBool(kAskDropsEnabledKey) ?? true;
  final askNotificationsEnabled =
      prefs.getBool(kAskNotificationsEnabledKey) ?? false;
  final askUseTasteContext = prefs.getBool(kAskUseTasteContextKey) ?? true;
  final offlineMode = prefs.getBool(kOfflineModeKey) ?? false;

  if (!askDropsEnabled ||
      !askNotificationsEnabled ||
      !askUseTasteContext ||
      offlineMode) {
    return;
  }

  if (!await Permission.notification.isGranted) return;

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final lastEval = prefs.getInt(kLastAskDropEvalTimeKey) ?? 0;
  if (nowMs - lastEval < _kMinBackgroundEvalInterval.inMilliseconds) {
    return;
  }

  final proxyOverride = prefs.getString(kAskProxyUrlOverrideKey)?.trim() ?? '';
  final proxyUrl = proxyOverride.isNotEmpty
      ? proxyOverride
      : kAskProxyBaseUrl.trim();
  final byokKey = prefs.getString(kDeepSeekApiKeyKey)?.trim() ?? '';
  final installId = prefs.getString(kAskInstallIdKey)?.trim() ?? '';

  final config = DeepSeekEndpointConfig(
    proxyBaseUrl: proxyUrl,
    byokApiKey: byokKey,
    installId: installId,
  );
  if (!config.isReady) return;

  final locale = PlatformDispatcher.instance.locale.languageCode;
  final datasource = DeepSeekHttpDatasource(readConfig: () => config);
  final chatRepo = DeepSeekLlmRepositoryImpl(datasource);

  final remoteConfig = await chatRepo.fetchPulseConfig(locale: locale);
  if (remoteConfig != null &&
      (!remoteConfig.enabled || remoteConfig.weeklyRemaining <= 0)) {
    return;
  }

  final db = createAppDatabase();
  try {
    final libraryRepo = LibraryRepositoryImpl(
      LibraryDao(db),
      PlaylistsDao(db),
      DownloadsDao(db),
      HistoryDao(db),
    );
    final storageRepo = AskStorageRepositoryImpl(db);
    final stateStore = PrefsAskPulseStateStore(prefs);

    MusicRepositoryImpl? musicRepo;
    final wantsCatalogCheck =
        remoteConfig == null ||
        remoteConfig.isTriggerEnabled('new_release') ||
        remoteConfig.isTriggerEnabled('new_podcast_episode');
    if (wantsCatalogCheck) {
      final hasArtistsOrPodcasts =
          (await libraryRepo.getAllFollowedArtists()).isNotEmpty ||
          (await libraryRepo.getAllLikedPodcasts()).isNotEmpty ||
          (await libraryRepo.getAllLikedAlbums()).any(
            (a) => a.artistId != null && a.artistId!.isNotEmpty,
          ) ||
          (await libraryRepo.getAllLikedSongs()).any(
            (s) => s.artistId != null && s.artistId!.isNotEmpty,
          );
      if (hasArtistsOrPodcasts) {
        final ytmusicDs = YtmusicDatasource();
        await ytmusicDs.initialize(
          gl: prefs.getString(kGlKey) ?? 'US',
          hl: prefs.getString(kHlKey) ?? 'en',
        );
        musicRepo = MusicRepositoryImpl(ytmusicDs, StreamDatasource());
      }
    }

    final useCase = EvaluateProactiveDropsUseCase(
      libraryRepo,
      storageRepo,
      chatRepo,
      musicRepository: musicRepo,
      stateStore: stateStore,
    );

    final drop = await useCase.execute(
      locale: locale,
      remoteConfig: remoteConfig,
      allowCatalogChecks: musicRepo != null,
    );
    await prefs.setInt(kLastAskDropEvalTimeKey, nowMs);

    if (drop != null) {
      await flutterLocalNotificationsPlugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await const FlutterAskNotificationService().showOrScheduleDrop(
        drop,
        quietStartHour: remoteConfig?.quietHoursStart ?? 22,
        quietEndHour: remoteConfig?.quietHoursEnd ?? 9,
      );
    }
  } finally {
    await db.close();
  }
}
