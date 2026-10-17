import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/music_search_intent.dart';
import '../../../providers/on_device_llm_provider.dart';
import 'search_provider.dart';

/// Session toggle for Ask mode (chip). Requires an installed model to take effect.
class AskModeEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) => state = value;

  void toggle() => state = !state;
}

final askModeEnabledProvider = NotifierProvider<AskModeEnabledNotifier, bool>(
  AskModeEnabledNotifier.new,
);

class AskInterpretation {
  const AskInterpretation({required this.originalQuery, required this.intent});

  final String originalQuery;
  final MusicSearchIntent intent;
}

class AskInterpretationNotifier extends Notifier<AskInterpretation?> {
  @override
  AskInterpretation? build() => null;

  void set(AskInterpretation? value) => state = value;

  void clear() => state = null;
}

final askInterpretationProvider =
    NotifierProvider<AskInterpretationNotifier, AskInterpretation?>(
      AskInterpretationNotifier.new,
    );

enum AskSubmitOutcome { keyword, interpreted, fallback }

/// Submits a search, optionally interpreting via the on-device LLM when Ask is on.
class AskSearchSubmitNotifier extends Notifier<AsyncValue<AskSubmitOutcome?>> {
  @override
  AsyncValue<AskSubmitOutcome?> build() => const AsyncData(null);

  Future<AskSubmitOutcome> submit(String query) async {
    final trimmed = query.trim();
    ref.read(askInterpretationProvider.notifier).clear();

    if (trimmed.isEmpty) {
      await ref.read(activeSearchQueryProvider.notifier).submit('');
      state = const AsyncData(AskSubmitOutcome.keyword);
      return AskSubmitOutcome.keyword;
    }

    final askOn = ref.read(askModeEnabledProvider);
    final modelReady = await ref.read(askModelReadyProvider.future);

    if (!askOn || !modelReady) {
      await ref.read(activeSearchQueryProvider.notifier).submit(trimmed);
      state = const AsyncData(AskSubmitOutcome.keyword);
      return AskSubmitOutcome.keyword;
    }

    state = const AsyncLoading();
    try {
      final intent = await ref
          .read(interpretSearchQueryUseCaseProvider)
          .execute(trimmed);

      if (intent == null) {
        await ref.read(activeSearchQueryProvider.notifier).submit(trimmed);
        state = const AsyncData(AskSubmitOutcome.fallback);
        return AskSubmitOutcome.fallback;
      }

      ref
          .read(askInterpretationProvider.notifier)
          .set(AskInterpretation(originalQuery: trimmed, intent: intent));
      ref.read(searchFilterProvider.notifier).update(intent.searchFilterIndex);
      await ref
          .read(activeSearchQueryProvider.notifier)
          .activate(
            intent.searchQuery,
            persistHistory: true,
            historyQuery: trimmed,
          );
      // Keep the field showing the user's natural-language phrase.
      ref.read(searchQueryProvider.notifier).update(trimmed);
      state = const AsyncData(AskSubmitOutcome.interpreted);
      return AskSubmitOutcome.interpreted;
    } catch (_) {
      await ref.read(activeSearchQueryProvider.notifier).submit(trimmed);
      state = const AsyncData(AskSubmitOutcome.fallback);
      return AskSubmitOutcome.fallback;
    }
  }
}

final askSearchSubmitProvider =
    NotifierProvider<AskSearchSubmitNotifier, AsyncValue<AskSubmitOutcome?>>(
      AskSearchSubmitNotifier.new,
    );
