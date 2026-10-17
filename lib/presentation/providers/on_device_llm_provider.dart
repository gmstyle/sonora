import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/ai/on_device_llm_datasource.dart';
import '../../data/repositories/on_device_llm_repository_impl.dart';
import '../../domain/repositories/on_device_llm_repository.dart';
import '../../domain/usecases/ai/interpret_search_query_use_case.dart';

final onDeviceLlmDatasourceProvider = Provider<OnDeviceLlmDatasource>((ref) {
  return OnDeviceLlmDatasource();
});

final onDeviceLlmRepositoryProvider = Provider<OnDeviceLlmRepository>((ref) {
  return OnDeviceLlmRepositoryImpl(ref.watch(onDeviceLlmDatasourceProvider));
});

final interpretSearchQueryUseCaseProvider =
    Provider<InterpretSearchQueryUseCase>((ref) {
      return InterpretSearchQueryUseCase(ref.watch(onDeviceLlmRepositoryProvider));
    });

/// Whether the Ask LiteRT model is installed and active.
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
