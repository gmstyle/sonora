import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/ai/translate_lyrics_use_case.dart';
import '../features/player/widgets/lyrics_view.dart';
import 'on_device_llm_provider.dart';

final translateLyricsUseCaseProvider = Provider<TranslateLyricsUseCase>((ref) {
  return TranslateLyricsUseCase(ref.watch(askLlmRepositoryProvider));
});

enum LyricsTranslationPhase { idle, loading, ready, error }

enum LyricsTranslationErrorKind { unavailable, noLyrics, empty, failed }

class LyricsTranslationState {
  const LyricsTranslationState({
    this.videoId,
    this.showTranslation = false,
    this.phase = LyricsTranslationPhase.idle,
    this.translation,
    this.errorKind,
  });

  final String? videoId;
  final bool showTranslation;
  final LyricsTranslationPhase phase;
  final String? translation;
  final LyricsTranslationErrorKind? errorKind;

  bool get hasTranslation =>
      translation != null && translation!.trim().isNotEmpty;
}

/// Lyrics-panel translation (cloud Ask, no Search grounding).
class LyricsTranslationNotifier extends Notifier<LyricsTranslationState> {
  @override
  LyricsTranslationState build() => const LyricsTranslationState();

  void showOriginal() {
    if (!state.showTranslation) return;
    state = LyricsTranslationState(
      videoId: state.videoId,
      showTranslation: false,
      phase:
          state.hasTranslation
              ? LyricsTranslationPhase.ready
              : LyricsTranslationPhase.idle,
      translation: state.translation,
    );
  }

  Future<void> showTranslated({
    required String videoId,
    required String targetLanguage,
  }) async {
    if (state.videoId == videoId &&
        state.hasTranslation &&
        state.phase == LyricsTranslationPhase.ready) {
      state = LyricsTranslationState(
        videoId: videoId,
        showTranslation: true,
        phase: LyricsTranslationPhase.ready,
        translation: state.translation,
      );
      return;
    }

    state = LyricsTranslationState(
      videoId: videoId,
      showTranslation: true,
      phase: LyricsTranslationPhase.loading,
    );

    final caps = await ref.read(askCapabilitiesProvider.future);
    if (!caps.canPlayerInsights) {
      state = LyricsTranslationState(
        videoId: videoId,
        showTranslation: true,
        phase: LyricsTranslationPhase.error,
        errorKind: LyricsTranslationErrorKind.unavailable,
      );
      return;
    }

    final lyricsText = await _resolveLyrics(videoId);
    if (lyricsText == null || lyricsText.trim().isEmpty) {
      state = LyricsTranslationState(
        videoId: videoId,
        showTranslation: true,
        phase: LyricsTranslationPhase.error,
        errorKind: LyricsTranslationErrorKind.noLyrics,
      );
      return;
    }

    try {
      final translation = await ref
          .read(translateLyricsUseCaseProvider)
          .execute(lyrics: lyricsText, targetLanguage: targetLanguage);

      if (state.videoId != videoId) return;

      if (translation == null || translation.isEmpty) {
        state = LyricsTranslationState(
          videoId: videoId,
          showTranslation: true,
          phase: LyricsTranslationPhase.error,
          errorKind: LyricsTranslationErrorKind.empty,
        );
        return;
      }

      state = LyricsTranslationState(
        videoId: videoId,
        showTranslation: true,
        phase: LyricsTranslationPhase.ready,
        translation: translation,
      );
    } catch (_) {
      if (state.videoId != videoId) return;
      state = LyricsTranslationState(
        videoId: videoId,
        showTranslation: true,
        phase: LyricsTranslationPhase.error,
        errorKind: LyricsTranslationErrorKind.failed,
      );
    }
  }

  void onTrackChanged(String? videoId) {
    if (videoId == null || videoId == state.videoId) return;
    state = const LyricsTranslationState();
  }

  Future<String?> _resolveLyrics(String videoId) async {
    final timed = await ref.read(lyricsProvider(videoId).future);
    if (timed != null && timed.timedLyricsData.isNotEmpty) {
      return timed.timedLyricsData
          .map((l) => l.lyricLine?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .join('\n');
    }
    return ref.read(plainLyricsProvider(videoId).future);
  }
}

final lyricsTranslationProvider =
    NotifierProvider<LyricsTranslationNotifier, LyricsTranslationState>(
      LyricsTranslationNotifier.new,
    );
