import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/ai/gemini_llm_datasource.dart';
import '../../data/datasources/ai/on_device_llm_datasource.dart';
import '../../data/repositories/gemini_llm_repository_impl.dart';
import '../../data/repositories/on_device_llm_repository_impl.dart';
import '../../data/repositories/routing_llm_repository.dart';
import '../../domain/models/ask_capabilities.dart';
import '../../domain/models/ask_mode.dart';
import '../../domain/repositories/llm_completion_repository.dart';
import '../../domain/repositories/on_device_llm_repository.dart';
import '../../domain/usecases/ai/interpret_search_query_use_case.dart';
import '../../domain/usecases/ai/rewrite_spotify_search_query_use_case.dart';
import 'connectivity_provider.dart';
import 'settings_provider.dart';

final onDeviceLlmDatasourceProvider = Provider<OnDeviceLlmDatasource>((ref) {
  return OnDeviceLlmDatasource();
});

final onDeviceLlmRepositoryProvider = Provider<OnDeviceLlmRepository>((ref) {
  return OnDeviceLlmRepositoryImpl(ref.watch(onDeviceLlmDatasourceProvider));
});

final geminiLlmDatasourceProvider = Provider<GeminiLlmDatasource>((ref) {
  return GeminiLlmDatasource();
});

final geminiLlmRepositoryProvider = Provider<GeminiLlmRepositoryImpl>((ref) {
  return GeminiLlmRepositoryImpl(ref.watch(geminiLlmDatasourceProvider));
});

/// Resolved Ask completion (on-device and/or Gemini).
final askLlmRepositoryProvider = Provider<LlmCompletionRepository>((ref) {
  final settings = ref.watch(settingsProvider);
  final offline = ref.watch(isOfflineProvider);
  return RoutingLlmRepository(
    onDevice: ref.watch(onDeviceLlmRepositoryProvider),
    cloud: ref.watch(geminiLlmRepositoryProvider),
    mode: () => settings.askMode,
    apiKey: () => settings.geminiApiKey,
    isOffline: () => offline,
  );
});

final interpretSearchQueryUseCaseProvider =
    Provider<InterpretSearchQueryUseCase>((ref) {
      return InterpretSearchQueryUseCase(ref.watch(askLlmRepositoryProvider));
    });

final rewriteSpotifySearchQueryUseCaseProvider =
    Provider<RewriteSpotifySearchQueryUseCase>((ref) {
      return RewriteSpotifySearchQueryUseCase(
        ref.watch(askLlmRepositoryProvider),
      );
    });

/// Whether any Ask backend can run completions right now.
final askLlmReadyProvider = FutureProvider<bool>((ref) {
  return ref.watch(askLlmRepositoryProvider).isReady();
});

/// Feature gates for the resolved backend (cloud vs on-device).
final askCapabilitiesProvider = FutureProvider<AskCapabilities>((ref) async {
  final router = ref.watch(askLlmRepositoryProvider);
  if (router is! RoutingLlmRepository) {
    final ready = await router.isReady();
    return AskCapabilities(ready ? AskLlmBackend.onDevice : AskLlmBackend.none);
  }
  final backend = await router.currentBackend();
  return AskCapabilities(backend);
});

/// Whether the on-device LiteRT model file is installed (Settings download UI).
final askModelReadyProvider = FutureProvider<bool>((ref) {
  return ref.watch(onDeviceLlmRepositoryProvider).isModelReady();
});

enum AskModelInstallPhase { idle, downloading, ready, error }

class AskModelInstallState {
  const AskModelInstallState({
    this.phase = AskModelInstallPhase.idle,
    this.progress = 0,
    this.errorMessage,
  });

  final AskModelInstallPhase phase;
  final double progress;
  final String? errorMessage;

  AskModelInstallState copyWith({
    AskModelInstallPhase? phase,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AskModelInstallState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AskModelInstallNotifier extends Notifier<AskModelInstallState> {
  @override
  AskModelInstallState build() => const AskModelInstallState();

  Future<void> download() async {
    if (state.phase == AskModelInstallPhase.downloading) return;
    state = const AskModelInstallState(
      phase: AskModelInstallPhase.downloading,
      progress: 0,
    );
    try {
      await ref
          .read(onDeviceLlmRepositoryProvider)
          .installModel(
            onProgress: (p) {
              state = state.copyWith(
                phase: AskModelInstallPhase.downloading,
                progress: p,
                clearError: true,
              );
            },
          );
      state = const AskModelInstallState(
        phase: AskModelInstallPhase.ready,
        progress: 1,
      );
      ref.invalidate(askModelReadyProvider);
      ref.invalidate(askLlmReadyProvider);
      ref.invalidate(askCapabilitiesProvider);
      unawaited(ref.read(onDeviceLlmRepositoryProvider).warmUp());
    } catch (e) {
      state = AskModelInstallState(
        phase: AskModelInstallPhase.error,
        progress: 0,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> uninstall() async {
    try {
      await ref.read(onDeviceLlmRepositoryProvider).uninstallModel();
      state = const AskModelInstallState();
      ref.invalidate(askModelReadyProvider);
      ref.invalidate(askLlmReadyProvider);
      ref.invalidate(askCapabilitiesProvider);
    } catch (e) {
      state = AskModelInstallState(
        phase: AskModelInstallPhase.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final askModelInstallProvider =
    NotifierProvider<AskModelInstallNotifier, AskModelInstallState>(
      AskModelInstallNotifier.new,
    );
