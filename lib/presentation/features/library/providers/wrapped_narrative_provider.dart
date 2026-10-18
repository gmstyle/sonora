import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/wrapped_narrative.dart';
import '../../../../domain/usecases/ai/generate_wrapped_narrative_use_case.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/stats_provider.dart';

final generateWrappedNarrativeUseCaseProvider =
    Provider<GenerateWrappedNarrativeUseCase>((ref) {
      return GenerateWrappedNarrativeUseCase(
        ref.watch(askLlmRepositoryProvider),
      );
    });

class WrappedNarrativeState {
  const WrappedNarrativeState({
    this.facts,
    this.narrative,
    this.generating = false,
    this.aiAttempted = false,
  });

  final WrappedFacts? facts;
  final WrappedNarrative? narrative;
  final bool generating;
  final bool aiAttempted;

  bool get hasAiNarrator => narrative?.fromAi == true;

  WrappedNarrativeState copyWith({
    WrappedFacts? facts,
    WrappedNarrative? narrative,
    bool? generating,
    bool? aiAttempted,
    bool clearNarrative = false,
  }) {
    return WrappedNarrativeState(
      facts: facts ?? this.facts,
      narrative: clearNarrative ? null : (narrative ?? this.narrative),
      generating: generating ?? this.generating,
      aiAttempted: aiAttempted ?? this.aiAttempted,
    );
  }
}

class WrappedNarrativeNotifier extends Notifier<WrappedNarrativeState> {
  String? _fingerprint;
  var _generation = 0;
  var _attempted = false;
  Future<void>? _job;

  @override
  WrappedNarrativeState build() => const WrappedNarrativeState();

  /// Generates cloud narrator pack when [canWrappedNarrative].
  Future<void> ensureGenerated({
    required StatsState stats,
    required String locale,
    bool force = false,
  }) async {
    if (!stats.isWrappedAvailable || stats.isLoading) return;

    final caps = await ref.read(askCapabilitiesProvider.future);
    if (!caps.canWrappedNarrative) {
      state = const WrappedNarrativeState(aiAttempted: true);
      return;
    }

    final facts = WrappedFacts(
      locale: locale,
      totalMinutes: stats.totalDurationMinutes,
      podcastMinutes: stats.podcastDurationMinutes,
      topArtistName:
          stats.topArtists.isNotEmpty ? stats.topArtists.first.name : null,
      topArtistPlays:
          stats.topArtists.isNotEmpty ? stats.topArtists.first.playCount : null,
      topSongTitle:
          stats.topSongs.isNotEmpty ? stats.topSongs.first.title : null,
      topSongArtist:
          stats.topSongs.isNotEmpty ? stats.topSongs.first.artist : null,
      topSongPlays:
          stats.topSongs.isNotEmpty ? stats.topSongs.first.playCount : null,
      peakHourBand: WrappedFacts.peakHourBandFrom(stats.hourlyDistribution),
      peakWeekday: WrappedFacts.peakWeekdayFrom(stats.weeklyDistribution),
    );

    final fp = facts.fingerprint;
    final inflight = _job;
    if (_fingerprint == fp && inflight != null) {
      await inflight;
      if (state.narrative?.fromAi == true) return;
      if (!force) return;
      _attempted = false;
    }

    if (force) _attempted = false;
    if (_fingerprint != fp) _attempted = false;
    if (_fingerprint == fp && state.generating) return;
    if (_fingerprint == fp && state.narrative?.fromAi == true && !force) {
      return;
    }
    if (_fingerprint == fp && _attempted && !force) return;

    _fingerprint = fp;
    final job = _run(facts);
    _job = job;
    try {
      await job;
    } finally {
      if (identical(_job, job)) _job = null;
    }
  }

  Future<void> _run(WrappedFacts facts) async {
    state = WrappedNarrativeState(
      facts: facts,
      narrative: null,
      generating: true,
      aiAttempted: false,
    );
    debugPrint('WrappedNarrative: generating ${facts.fingerprint}');

    final gen = ++_generation;
    try {
      final ai = await ref
          .read(generateWrappedNarrativeUseCaseProvider)
          .execute(facts);
      if (gen != _generation) return;
      _attempted = true;
      state = WrappedNarrativeState(
        facts: facts,
        narrative: ai,
        generating: false,
        aiAttempted: true,
      );
    } catch (e, st) {
      if (gen != _generation) return;
      _attempted = true;
      debugPrint('WrappedNarrative: $e\n$st');
      state = WrappedNarrativeState(
        facts: facts,
        narrative: null,
        generating: false,
        aiAttempted: true,
      );
    }
  }
}

final wrappedNarrativeProvider =
    NotifierProvider<WrappedNarrativeNotifier, WrappedNarrativeState>(
      WrappedNarrativeNotifier.new,
    );
