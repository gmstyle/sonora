import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ai_constants.dart';
import '../../data/datasources/ai/deepseek_http_datasource.dart';
import '../../data/repositories/deepseek_llm_repository_impl.dart';
import '../../domain/models/ask_capabilities.dart';
import '../../domain/models/ask_chat_models.dart';
import '../../domain/models/queue_track.dart';
import '../../domain/repositories/grounded_llm_repository.dart';
import '../../domain/repositories/llm_chat_repository.dart';
import '../../domain/repositories/llm_completion_repository.dart';
import '../../domain/usecases/ai/apply_ask_playlist_write_use_case.dart';
import '../../domain/usecases/ai/ask_agent_use_case.dart';
import '../../domain/usecases/ai/ask_tool_executor.dart';
import '../../domain/usecases/ai/evaluate_proactive_drops_use_case.dart';
import '../../domain/usecases/ai/resolve_spotify_ambiguous_tracks_use_case.dart';
import '../../domain/usecases/ai/rewrite_spotify_search_query_use_case.dart';
import 'ask_storage_provider.dart';
import 'connectivity_provider.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';
import 'player_provider.dart';
import 'settings_provider.dart';

/// Effective Ask proxy URL (Settings override wins over build-time define).
final askEffectiveProxyUrlProvider = Provider<String>((ref) {
  final override = ref.watch(
    settingsProvider.select((s) => s.askProxyUrlOverride.trim()),
  );
  if (override.isNotEmpty) return override;
  return kAskProxyBaseUrl.trim();
});

class AskQuotaNotifier extends Notifier<AskQuotaInfo> {
  @override
  AskQuotaInfo build() {
    final settings = ref.watch(settingsProvider);
    final proxyUrl = ref.watch(askEffectiveProxyUrlProvider);
    final hasByok = (settings.deepseekApiKey?.trim().isNotEmpty ?? false);
    if (hasByok) return AskQuotaInfo.unlimited();
    if (proxyUrl.isEmpty) return AskQuotaInfo.unconfigured();
    return const AskQuotaInfo(
      remaining: kAskDailyCreditLimit,
      limit: kAskDailyCreditLimit,
    );
  }

  void update(AskQuotaInfo quota) {
    state = quota;
  }

  Future<void> refresh() async {
    if (ref.read(isOfflineProvider)) return;
    try {
      final caps = await ref.read(askCapabilitiesProvider.future);
      if (!ref.mounted || caps.backend != AskBackendMode.proxy) return;
      final info = await ref.read(askChatRepositoryProvider).fetchQuota();
      if (!ref.mounted) return;
      if (info != null) state = info;
    } catch (_) {}
  }
}

final askQuotaProvider = NotifierProvider<AskQuotaNotifier, AskQuotaInfo>(
  AskQuotaNotifier.new,
);

final deepSeekHttpDatasourceProvider = Provider<DeepSeekHttpDatasource>((ref) {
  return DeepSeekHttpDatasource(
    readConfig: () {
      final settings = ref.read(settingsProvider);
      final override = settings.askProxyUrlOverride.trim();
      final proxyUrl = override.isNotEmpty ? override : kAskProxyBaseUrl.trim();
      return DeepSeekEndpointConfig(
        proxyBaseUrl: proxyUrl,
        byokApiKey: settings.deepseekApiKey?.trim() ?? '',
        installId: settings.askInstallId,
      );
    },
  );
});

final deepSeekLlmRepositoryProvider = Provider<DeepSeekLlmRepositoryImpl>((
  ref,
) {
  return DeepSeekLlmRepositoryImpl(
    ref.watch(deepSeekHttpDatasourceProvider),
    onQuotaUpdated: (quota) {
      ref.read(askQuotaProvider.notifier).update(quota);
    },
  );
});

final askLlmRepositoryProvider = Provider<LlmCompletionRepository>((ref) {
  return ref.watch(deepSeekLlmRepositoryProvider);
});

final askGroundedLlmRepositoryProvider = Provider<GroundedLlmRepository>((ref) {
  return ref.watch(deepSeekLlmRepositoryProvider);
});

final askChatRepositoryProvider = Provider<LlmChatRepository>((ref) {
  return ref.watch(deepSeekLlmRepositoryProvider);
});

final askCapabilitiesProvider = FutureProvider<AskCapabilities>((ref) async {
  final settings = ref.watch(settingsProvider);
  final proxyUrl = ref.watch(askEffectiveProxyUrlProvider);
  final isOffline = ref.watch(isOfflineProvider);

  final hasByok = (settings.deepseekApiKey?.trim().isNotEmpty ?? false);
  final backend = hasByok
      ? AskBackendMode.byok
      : (proxyUrl.isNotEmpty
            ? AskBackendMode.proxy
            : AskBackendMode.unconfigured);

  return AskCapabilities(backend: backend, isOffline: isOffline);
});

final askLlmReadyProvider = FutureProvider<bool>((ref) async {
  final caps = await ref.watch(askCapabilitiesProvider.future);
  return caps.canUseAsk;
});

final rewriteSpotifySearchQueryUseCaseProvider =
    Provider<RewriteSpotifySearchQueryUseCase>((ref) {
      return RewriteSpotifySearchQueryUseCase(
        ref.watch(askLlmRepositoryProvider),
      );
    });

final resolveSpotifyAmbiguousTracksUseCaseProvider =
    Provider<ResolveSpotifyAmbiguousTracksUseCase>((ref) {
      return ResolveSpotifyAmbiguousTracksUseCase(
        ref.watch(askChatRepositoryProvider),
      );
    });

final askAgentUseCaseProvider = Provider<AskAgentUseCase>((ref) {
  return AskAgentUseCase(ref.watch(askChatRepositoryProvider));
});

final applyAskPlaylistWriteUseCaseProvider =
    Provider<ApplyAskPlaylistWriteUseCase>((ref) {
      return ApplyAskPlaylistWriteUseCase(ref.watch(libraryRepositoryProvider));
    });

final evaluateProactiveDropsUseCaseProvider =
    Provider<EvaluateProactiveDropsUseCase>((ref) {
      return EvaluateProactiveDropsUseCase(
        ref.watch(libraryRepositoryProvider),
        ref.watch(askStorageRepositoryProvider),
        ref.watch(askChatRepositoryProvider),
      );
    });

/// Builds a fresh per-turn [AskToolExecutor] with access to Drift library,
/// YouTube Music catalog, and the player's current track.
AskToolExecutor createAskToolExecutor(Ref ref) {
  final settings = ref.read(settingsProvider);
  return AskToolExecutor(
    libraryRepository: ref.read(libraryRepositoryProvider),
    musicRepository: ref.read(musicRepositoryProvider),
    useTasteContext: settings.askUseTasteContext,
    readNowPlaying: () {
      final player = ref.read(playerStateProvider);
      final song = player.currentSong;
      if (song == null) return null;
      final track = QueueTrack.fromMediaItem(song);
      return AskNowPlayingSnapshot(
        videoId: track.videoId,
        title: track.title,
        artist: track.artist ?? '',
        album: track.album,
        durationSec: track.duration?.inSeconds,
        isEpisode: track.isEpisode,
      );
    },
  );
}
