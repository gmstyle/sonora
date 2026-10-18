import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/music_search_intent.dart';
import '../../domain/usecases/ai/assemble_moment_mix_use_case.dart';
import '../../domain/usecases/ai/interpret_mix_query_use_case.dart';
import 'connectivity_provider.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';
import 'on_device_llm_provider.dart';
import 'player_provider.dart';

final interpretMixQueryUseCaseProvider = Provider<InterpretMixQueryUseCase>((
  ref,
) {
  return InterpretMixQueryUseCase(ref.watch(askLlmRepositoryProvider));
});

final assembleMomentMixUseCaseProvider = Provider<AssembleMomentMixUseCase>((
  ref,
) {
  return AssembleMomentMixUseCase(
    ref.watch(libraryRepositoryProvider),
    ref.watch(musicRepositoryProvider),
  );
});

enum MomentMixPhase { idle, interpreting, assembling, ready, error }

class MomentMixState {
  const MomentMixState({
    this.phase = MomentMixPhase.idle,
    this.phrase = '',
    this.intent,
    this.tracks = const [],
    this.errorKind,
  });

  final MomentMixPhase phase;
  final String phrase;
  final MusicSearchIntent? intent;
  final List<dynamic> tracks;
  final MomentMixErrorKind? errorKind;

  bool get hasMix => tracks.isNotEmpty && intent != null;

  MomentMixState copyWith({
    MomentMixPhase? phase,
    String? phrase,
    MusicSearchIntent? intent,
    List<dynamic>? tracks,
    MomentMixErrorKind? errorKind,
    bool clearIntent = false,
    bool clearTracks = false,
    bool clearError = false,
  }) {
    return MomentMixState(
      phase: phase ?? this.phase,
      phrase: phrase ?? this.phrase,
      intent: clearIntent ? null : (intent ?? this.intent),
      tracks: clearTracks ? const [] : (tracks ?? this.tracks),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
    );
  }
}

enum MomentMixErrorKind {
  modelUnavailable,
  interpretFailed,
  emptyQueue,
  offlineNeedsYtm,
  playFailed,
}

class MomentMixNotifier extends Notifier<MomentMixState> {
  @override
  MomentMixState build() => const MomentMixState();

  void clear() {
    state = const MomentMixState();
  }

  /// Interprets [phrase] and assembles a capped queue.
  Future<MomentMixErrorKind?> generate(String phrase) async {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return null;

    final modelReady = await ref.read(askLlmReadyProvider.future);
    if (!modelReady) {
      state = MomentMixState(
        phase: MomentMixPhase.error,
        phrase: trimmed,
        errorKind: MomentMixErrorKind.modelUnavailable,
      );
      return MomentMixErrorKind.modelUnavailable;
    }

    state = MomentMixState(phase: MomentMixPhase.interpreting, phrase: trimmed);

    final intent = await ref
        .read(interpretMixQueryUseCaseProvider)
        .execute(trimmed);

    if (intent == null) {
      state = MomentMixState(
        phase: MomentMixPhase.error,
        phrase: trimmed,
        errorKind: MomentMixErrorKind.interpretFailed,
      );
      return MomentMixErrorKind.interpretFailed;
    }

    final offline = ref.read(isOfflineProvider);
    if (offline && intent.source == MixSource.ytm) {
      state = MomentMixState(
        phase: MomentMixPhase.error,
        phrase: trimmed,
        intent: intent,
        errorKind: MomentMixErrorKind.offlineNeedsYtm,
      );
      return MomentMixErrorKind.offlineNeedsYtm;
    }

    state = state.copyWith(
      phase: MomentMixPhase.assembling,
      intent: intent,
      clearError: true,
      clearTracks: true,
    );

    try {
      final queue = await ref
          .read(assembleMomentMixUseCaseProvider)
          .execute(intent: intent, allowYtm: !offline);

      if (queue.isEmpty) {
        state = MomentMixState(
          phase: MomentMixPhase.error,
          phrase: trimmed,
          intent: intent,
          errorKind: MomentMixErrorKind.emptyQueue,
        );
        return MomentMixErrorKind.emptyQueue;
      }

      state = MomentMixState(
        phase: MomentMixPhase.ready,
        phrase: trimmed,
        intent: intent,
        tracks: queue.tracks,
      );
      return null;
    } catch (_) {
      state = MomentMixState(
        phase: MomentMixPhase.error,
        phrase: trimmed,
        intent: intent,
        errorKind: MomentMixErrorKind.emptyQueue,
      );
      return MomentMixErrorKind.emptyQueue;
    }
  }

  Future<MomentMixErrorKind?> play() async {
    final tracks = state.tracks;
    if (tracks.isEmpty) return MomentMixErrorKind.emptyQueue;
    try {
      await ref
          .read(playerStateProvider.notifier)
          .playSmartMix(tracks, startIndex: 0);
      return null;
    } catch (_) {
      return MomentMixErrorKind.playFailed;
    }
  }
}

final momentMixProvider = NotifierProvider<MomentMixNotifier, MomentMixState>(
  MomentMixNotifier.new,
);
