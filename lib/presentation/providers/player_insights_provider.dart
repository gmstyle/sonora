import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/grounded_llm_result.dart';
import '../../domain/usecases/ai/generate_track_insights_use_case.dart';
import 'on_device_llm_provider.dart';

final generateTrackInsightsUseCaseProvider =
    Provider<GenerateTrackInsightsUseCase>((ref) {
      return GenerateTrackInsightsUseCase(
        ref.watch(geminiLlmRepositoryProvider),
      );
    });

enum PlayerInsightsPhase { idle, loading, ready, error }

enum PlayerInsightsErrorKind { unavailable, noSources, empty, failed }

class PlayerInsightsState {
  const PlayerInsightsState({
    this.isOpen = false,
    this.phase = PlayerInsightsPhase.idle,
    this.videoId,
    this.bullets = const [],
    this.sources = const [],
    this.errorKind,
  });

  final bool isOpen;
  final PlayerInsightsPhase phase;
  final String? videoId;
  final List<String> bullets;
  final List<GroundedSource> sources;
  final PlayerInsightsErrorKind? errorKind;

  PlayerInsightsState copyWith({
    bool? isOpen,
    PlayerInsightsPhase? phase,
    String? videoId,
    List<String>? bullets,
    List<GroundedSource>? sources,
    PlayerInsightsErrorKind? errorKind,
    bool clearError = false,
    bool clearResults = false,
  }) {
    return PlayerInsightsState(
      isOpen: isOpen ?? this.isOpen,
      phase: phase ?? this.phase,
      videoId: videoId ?? this.videoId,
      bullets: clearResults ? const [] : (bullets ?? this.bullets),
      sources: clearResults ? const [] : (sources ?? this.sources),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
    );
  }
}

/// One-tap curiosities overlay for the now-playing track (cloud + Search).
class PlayerInsightsNotifier extends Notifier<PlayerInsightsState> {
  @override
  PlayerInsightsState build() => const PlayerInsightsState();

  void dismiss() {
    if (!state.isOpen) return;
    state = state.copyWith(isOpen: false);
  }

  /// Opens the panel and starts generation. Reuses cached bullets for the
  /// same [videoId] when already ready.
  Future<void> openInsights({
    required String videoId,
    required String title,
    required String artist,
    String? album,
    required String locale,
  }) async {
    final sameTrack = state.videoId == videoId;
    final canReuse =
        sameTrack &&
        state.phase == PlayerInsightsPhase.ready &&
        state.bullets.isNotEmpty;

    if (canReuse) {
      state = state.copyWith(isOpen: true);
      return;
    }

    state = PlayerInsightsState(
      isOpen: true,
      phase: PlayerInsightsPhase.loading,
      videoId: videoId,
    );

    final caps = await ref.read(askCapabilitiesProvider.future);
    if (!caps.canPlayerInsights) {
      state = state.copyWith(
        phase: PlayerInsightsPhase.error,
        errorKind: PlayerInsightsErrorKind.unavailable,
      );
      return;
    }

    try {
      final result = await ref
          .read(generateTrackInsightsUseCaseProvider)
          .execute(title: title, artist: artist, album: album, locale: locale);

      // Drop stale responses after a track change / dismiss.
      if (state.videoId != videoId) return;
      final stillOpen = state.isOpen;

      if (result == null || result.isEmpty) {
        state = state.copyWith(
          isOpen: stillOpen,
          phase: PlayerInsightsPhase.error,
          errorKind: PlayerInsightsErrorKind.noSources,
        );
        return;
      }

      state = PlayerInsightsState(
        isOpen: stillOpen,
        phase: PlayerInsightsPhase.ready,
        videoId: videoId,
        bullets: result.bullets,
        sources: result.sources,
      );
    } catch (_) {
      if (state.videoId != videoId) return;
      state = state.copyWith(
        phase: PlayerInsightsPhase.error,
        errorKind: PlayerInsightsErrorKind.failed,
      );
    }
  }

  Future<void> retry({
    required String videoId,
    required String title,
    required String artist,
    String? album,
    required String locale,
  }) {
    state = PlayerInsightsState(isOpen: true, videoId: videoId);
    return openInsights(
      videoId: videoId,
      title: title,
      artist: artist,
      album: album,
      locale: locale,
    );
  }

  void onTrackChanged(String? videoId) {
    if (videoId == null || videoId == state.videoId) return;
    state = const PlayerInsightsState();
  }
}

final playerInsightsProvider =
    NotifierProvider<PlayerInsightsNotifier, PlayerInsightsState>(
      PlayerInsightsNotifier.new,
    );
