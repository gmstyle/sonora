import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/playlist_import.dart';
import '../../domain/usecases/playlist/import_spotify_playlist_use_case.dart';
import '../../domain/usecases/playlist/refresh_linked_playlist_use_case.dart';
import 'download_provider.dart';
import 'import_playlist_providers.dart';
import 'on_device_llm_provider.dart';
import 'refresh_linked_playlist_use_case_provider.dart';

enum PlaylistImportJobPhase {
  idle,
  matching,
  awaitingReview,
  saving,
  completed,
  failed,
  cancelled,
}

enum PlaylistImportJobKind {
  spotifyImport,
  youtubeImport,
  spotifySync,
  youtubeSync,
}

/// Who should present review / completion UI for the active job.
enum PlaylistImportUiOwner { dialog, host }

/// Background playlist import / sync job (survives dialog dismiss).
class PlaylistImportJobState {
  const PlaylistImportJobState({
    this.phase = PlaylistImportJobPhase.idle,
    this.jobKind,
    this.minimized = false,
    this.uiOwner = PlaylistImportUiOwner.dialog,
    this.current = 0,
    this.total = 0,
    this.trackLabel,
    this.aiModelReady = false,
    this.playlistName,
    this.importPlan,
    this.refreshPlan,
    this.importResult,
    this.syncResult,
    this.errorMessage,
    this.needsUiAttention = false,
  });

  final PlaylistImportJobPhase phase;
  final PlaylistImportJobKind? jobKind;
  final bool minimized;
  final PlaylistImportUiOwner uiOwner;
  final int current;
  final int total;
  final String? trackLabel;
  final bool aiModelReady;
  final String? playlistName;
  final SpotifyImportPlan? importPlan;
  final SpotifyRefreshPlan? refreshPlan;
  final PlaylistImportResult? importResult;
  final PlaylistSyncResult? syncResult;
  final String? errorMessage;

  /// Set when review is ready or job finished — the [uiOwner] should react.
  final bool needsUiAttention;

  bool get isActive =>
      phase == PlaylistImportJobPhase.matching ||
      phase == PlaylistImportJobPhase.awaitingReview ||
      phase == PlaylistImportJobPhase.saving;

  bool get showInDockBanner =>
      minimized &&
      (phase == PlaylistImportJobPhase.matching ||
          phase == PlaylistImportJobPhase.saving ||
          phase == PlaylistImportJobPhase.awaitingReview);

  bool get isSpotify =>
      jobKind == PlaylistImportJobKind.spotifyImport ||
      jobKind == PlaylistImportJobKind.spotifySync;

  double? get progressValue {
    if (total <= 0 || phase != PlaylistImportJobPhase.matching) return null;
    return (current / total).clamp(0.0, 1.0);
  }

  PlaylistImportJobState copyWith({
    PlaylistImportJobPhase? phase,
    PlaylistImportJobKind? jobKind,
    bool? minimized,
    PlaylistImportUiOwner? uiOwner,
    int? current,
    int? total,
    String? trackLabel,
    bool clearTrackLabel = false,
    bool? aiModelReady,
    String? playlistName,
    SpotifyImportPlan? importPlan,
    SpotifyRefreshPlan? refreshPlan,
    PlaylistImportResult? importResult,
    PlaylistSyncResult? syncResult,
    String? errorMessage,
    bool clearError = false,
    bool? needsUiAttention,
    bool clearPlans = false,
  }) {
    return PlaylistImportJobState(
      phase: phase ?? this.phase,
      jobKind: jobKind ?? this.jobKind,
      minimized: minimized ?? this.minimized,
      uiOwner: uiOwner ?? this.uiOwner,
      current: current ?? this.current,
      total: total ?? this.total,
      trackLabel: clearTrackLabel ? null : (trackLabel ?? this.trackLabel),
      aiModelReady: aiModelReady ?? this.aiModelReady,
      playlistName: playlistName ?? this.playlistName,
      importPlan: clearPlans ? null : (importPlan ?? this.importPlan),
      refreshPlan: clearPlans ? null : (refreshPlan ?? this.refreshPlan),
      importResult: importResult ?? this.importResult,
      syncResult: syncResult ?? this.syncResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      needsUiAttention: needsUiAttention ?? this.needsUiAttention,
    );
  }
}

class PlaylistImportJobNotifier extends Notifier<PlaylistImportJobState> {
  var _generation = 0;
  var _cancelRequested = false;

  @override
  PlaylistImportJobState build() => const PlaylistImportJobState();

  bool get _aborted => _cancelRequested;

  void minimize() {
    if (!state.isActive &&
        state.phase != PlaylistImportJobPhase.awaitingReview) {
      return;
    }
    state = state.copyWith(
      minimized: true,
      uiOwner: PlaylistImportUiOwner.host,
    );
  }

  void expand() {
    if (!state.isActive &&
        state.phase != PlaylistImportJobPhase.awaitingReview) {
      return;
    }
    state = state.copyWith(
      minimized: false,
      uiOwner: PlaylistImportUiOwner.host,
      needsUiAttention: true,
    );
  }

  void acknowledgeUiAttention() {
    if (!state.needsUiAttention) return;
    state = state.copyWith(needsUiAttention: false);
  }

  void clearTerminal() {
    if (state.isActive) return;
    state = const PlaylistImportJobState();
  }

  Future<void> cancel() async {
    if (!state.isActive &&
        state.phase != PlaylistImportJobPhase.awaitingReview) {
      return;
    }
    _cancelRequested = true;
    _generation++;
    state = state.copyWith(
      phase: PlaylistImportJobPhase.cancelled,
      minimized: false,
      clearTrackLabel: true,
      clearPlans: true,
      needsUiAttention: false,
    );
  }

  Future<void> startSpotifyImport(String playlistId) async {
    await _runJob(
      kind: PlaylistImportJobKind.spotifyImport,
      body: (gen) async {
        final ready = await _modelReady();
        if (gen != _generation) return;
        state = state.copyWith(aiModelReady: ready);

        final useCase = ref.read(importSpotifyPlaylistUseCaseProvider);
        final plan = await useCase.prepare(
          playlistId,
          tryRewrite: ready,
          shouldAbort: () => _aborted || gen != _generation,
          onProgress: (p) {
            if (gen != _generation) return;
            state = state.copyWith(
              current: p.current,
              total: p.total,
              trackLabel: p.trackLabel,
              playlistName: state.playlistName,
            );
          },
        );
        if (gen != _generation || _aborted) return;

        state = state.copyWith(
          playlistName: plan.snapshot.name,
          importPlan: plan,
        );

        if (plan.ambiguous.isNotEmpty) {
          state = state.copyWith(
            phase: PlaylistImportJobPhase.awaitingReview,
            clearTrackLabel: true,
            needsUiAttention: true,
          );
          return;
        }

        await _commitImport(gen, plan, const {});
      },
    );
  }

  Future<void> startYoutubeImport(String playlistUrlOrId) async {
    await _runJob(
      kind: PlaylistImportJobKind.youtubeImport,
      body: (gen) async {
        state = state.copyWith(phase: PlaylistImportJobPhase.saving);
        final result = await ref
            .read(importRemotePlaylistUseCaseProvider)
            .execute(playlistUrlOrId);
        if (gen != _generation || _aborted) return;
        state = state.copyWith(
          phase: PlaylistImportJobPhase.completed,
          importResult: result,
          playlistName: result.name,
          needsUiAttention: true,
          minimized: state.minimized,
        );
      },
    );
  }

  Future<void> startSpotifySync(int localPlaylistId) async {
    await _runJob(
      kind: PlaylistImportJobKind.spotifySync,
      body: (gen) async {
        final ready = await _modelReady();
        if (gen != _generation) return;
        state = state.copyWith(aiModelReady: ready);

        final refresh = ref.read(refreshLinkedPlaylistUseCaseProvider);
        final plan = await refresh.prepareSpotify(
          localPlaylistId,
          tryRewrite: ready,
          shouldAbort: () => _aborted || gen != _generation,
          onProgress: (p) {
            if (gen != _generation) return;
            state = state.copyWith(
              current: p.current,
              total: p.total,
              trackLabel: p.trackLabel,
            );
          },
        );
        if (gen != _generation || _aborted) return;

        state = state.copyWith(
          playlistName: plan.snapshot.name,
          refreshPlan: plan,
        );

        if (plan.ambiguous.isNotEmpty) {
          state = state.copyWith(
            phase: PlaylistImportJobPhase.awaitingReview,
            clearTrackLabel: true,
            needsUiAttention: true,
          );
          return;
        }

        await _commitSync(gen, plan, const {});
      },
    );
  }

  Future<void> startYoutubeSync(int localPlaylistId) async {
    await _runJob(
      kind: PlaylistImportJobKind.youtubeSync,
      body: (gen) async {
        state = state.copyWith(phase: PlaylistImportJobPhase.saving);
        final result = await ref
            .read(refreshLinkedPlaylistUseCaseProvider)
            .execute(localPlaylistId);
        if (gen != _generation || _aborted) return;
        state = state.copyWith(
          phase: PlaylistImportJobPhase.completed,
          syncResult: result,
          playlistName: result.name,
          needsUiAttention: true,
        );
      },
    );
  }

  /// Continue after the user finishes (or skips) the review sheet.
  Future<void> submitReview(Map<int, ImportedTrackCandidate?> choices) async {
    final gen = _generation;
    if (state.phase != PlaylistImportJobPhase.awaitingReview) return;

    final importPlan = state.importPlan;
    final refreshPlan = state.refreshPlan;
    state = state.copyWith(
      phase: PlaylistImportJobPhase.saving,
      clearTrackLabel: true,
      needsUiAttention: false,
    );

    try {
      if (importPlan != null) {
        await _commitImport(gen, importPlan, choices);
      } else if (refreshPlan != null) {
        await _commitSync(gen, refreshPlan, choices);
      }
    } catch (e) {
      if (gen != _generation) return;
      _fail(e);
    }
  }

  Future<void> _commitImport(
    int gen,
    SpotifyImportPlan plan,
    Map<int, ImportedTrackCandidate?> choices,
  ) async {
    state = state.copyWith(phase: PlaylistImportJobPhase.saving);
    final resolved = ImportSpotifyPlaylistUseCase.applyReviewChoices(
      plan,
      choices,
    );
    final result = await ref
        .read(importSpotifyPlaylistUseCaseProvider)
        .commit(resolved);
    if (gen != _generation || _aborted) return;
    state = state.copyWith(
      phase: PlaylistImportJobPhase.completed,
      importResult: result,
      playlistName: result.name,
      clearPlans: true,
      needsUiAttention: true,
    );
  }

  Future<void> _commitSync(
    int gen,
    SpotifyRefreshPlan plan,
    Map<int, ImportedTrackCandidate?> choices,
  ) async {
    state = state.copyWith(phase: PlaylistImportJobPhase.saving);
    final resolved = RefreshLinkedPlaylistUseCase.applySpotifyReviewChoices(
      plan,
      choices,
    );
    final result = await ref
        .read(refreshLinkedPlaylistUseCaseProvider)
        .commitSpotify(resolved);
    if (gen != _generation || _aborted) return;
    state = state.copyWith(
      phase: PlaylistImportJobPhase.completed,
      syncResult: result,
      playlistName: result.name,
      clearPlans: true,
      needsUiAttention: true,
    );
  }

  Future<void> _runJob({
    required PlaylistImportJobKind kind,
    required Future<void> Function(int generation) body,
  }) async {
    if (state.isActive ||
        state.phase == PlaylistImportJobPhase.awaitingReview) {
      debugPrint('Playlist import job already active; ignoring start');
      return;
    }
    _cancelRequested = false;
    final gen = ++_generation;
    state = PlaylistImportJobState(
      phase: PlaylistImportJobPhase.matching,
      jobKind: kind,
      aiModelReady: false,
      minimized: false,
      uiOwner: PlaylistImportUiOwner.dialog,
    );
    try {
      await body(gen);
    } on PlaylistAlreadyLinkedException {
      // Reset so the dialog can offer "Sync instead?" and start a new job.
      if (gen == _generation) {
        state = const PlaylistImportJobState();
      }
      rethrow;
    } on PlaylistImportCancelledException {
      if (gen != _generation) return;
      state = state.copyWith(
        phase: PlaylistImportJobPhase.cancelled,
        clearTrackLabel: true,
        clearPlans: true,
        needsUiAttention: false,
        minimized: false,
      );
    } catch (e) {
      if (gen != _generation) return;
      if (e is PlaylistImportCancelledException) {
        state = state.copyWith(
          phase: PlaylistImportJobPhase.cancelled,
          clearPlans: true,
          minimized: false,
        );
        return;
      }
      _fail(e);
    }
  }

  void _fail(Object e) {
    debugPrint('Playlist import job failed: $e');
    state = state.copyWith(
      phase: PlaylistImportJobPhase.failed,
      errorMessage: e.toString().replaceAll('Exception: ', ''),
      clearTrackLabel: true,
      clearPlans: true,
      needsUiAttention: true,
    );
  }

  Future<bool> _modelReady() async {
    try {
      return await ref.read(askModelReadyProvider.future);
    } catch (_) {
      return false;
    }
  }
}

final playlistImportJobProvider =
    NotifierProvider<PlaylistImportJobNotifier, PlaylistImportJobState>(
      PlaylistImportJobNotifier.new,
    );

/// Whether any dock banner (import or download) is visible — for shell insets.
final dockBannersVisibleProvider = Provider<bool>((ref) {
  final import = ref.watch(playlistImportJobProvider);
  final downloads = ref.watch(downloadBannerSummaryProvider);
  return import.showInDockBanner || downloads != null;
});
