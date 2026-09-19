import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/download_group.dart';
import '../../domain/models/library_models.dart';
import '../../domain/usecases/download/download_exceptions.dart';
import '../../domain/utils/download_grouping.dart';
import '../../l10n/app_localizations.dart';
import 'delete_download_use_case_provider.dart';
import 'download_notification_service.dart';
import 'library_repository_provider.dart';
import 'settings_provider.dart';
import 'start_download_use_case_provider.dart';

// ── Download state models ──────────────────────────────────────────────────

enum DownloadStatus { pending, downloading, completed, error }

enum DownloadError { wifiRestricted, network, storage, unknown }

enum DownloadBannerAction { cancelItem, cancelBatch, cancelAll }

/// Immutable snapshot of one in-flight / queued / just-finished download.
class ActiveDownload {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final double? speedBytesPerSec;
  final DownloadError? error;
  final String? batchId;
  final String? batchName;
  final int? batchTotal;

  const ActiveDownload({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.status = DownloadStatus.pending,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec,
    this.error,
    this.batchId,
    this.batchName,
    this.batchTotal,
  });

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  Duration? get remaining {
    final speed = speedBytesPerSec;
    if (speed == null || speed <= 0 || receivedBytes >= totalBytes) {
      return null;
    }
    return Duration(seconds: ((totalBytes - receivedBytes) / speed).ceil());
  }

  ActiveDownload copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? speedBytesPerSec,
    bool clearSpeed = false,
    DownloadError? error,
  }) {
    return ActiveDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec:
          clearSpeed ? null : (speedBytesPerSec ?? this.speedBytesPerSec),
      error: error ?? this.error,
      batchId: batchId,
      batchName: batchName,
      batchTotal: batchTotal,
    );
  }
}

/// Session progress for a bulk enqueue (album / playlist / podcast).
class DownloadBatchProgress {
  final String id;
  final String name;
  final int total;
  final int completed;

  const DownloadBatchProgress({
    required this.id,
    required this.name,
    required this.total,
    required this.completed,
  });

  int get remaining => (total - completed).clamp(0, total);
}

/// Derived UI model for the persistent in-app download banner.
class DownloadBannerSummary {
  final String title;
  final String? subtitle;
  final DownloadBannerAction action;
  final String? targetId;
  final double? progress;

  const DownloadBannerSummary({
    required this.title,
    this.subtitle,
    required this.action,
    this.targetId,
    this.progress,
  });
}

// ── Providers ─────────────────────────────────────────────────────────────

final allDownloadsProvider = StreamProvider<List<DownloadModel>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchCompletedDownloads();
});

/// Completed downloads grouped by collection / inferred folder / Singles.
final downloadGroupsProvider = Provider<List<DownloadGroup>>((ref) {
  final downloads = ref.watch(allDownloadsProvider).asData?.value ?? const [];
  return groupCompletedDownloads(downloads);
});

final activeDownloadsProvider =
    NotifierProvider<DownloadsNotifier, Map<String, ActiveDownload>>(
      DownloadsNotifier.new,
    );

/// Completed counts for active batches (survives per-item flash removal).
final downloadBatchesProvider = Provider<Map<String, DownloadBatchProgress>>((
  ref,
) {
  // Rebuild whenever queue items change; batch counters live on the notifier.
  ref.watch(activeDownloadsProvider);
  return ref.read(activeDownloadsProvider.notifier).batchProgress;
});

final downloadedIdsProvider = Provider<Set<String>>((ref) {
  final allDownloads = ref.watch(allDownloadsProvider);
  return allDownloads.asData?.value.map((d) => d.videoId).toSet() ?? {};
});

/// Aggregate banner state — presentation-only, derived from the notifier.
final downloadBannerSummaryProvider = Provider<DownloadBannerSummary?>((ref) {
  final active = ref.watch(activeDownloadsProvider);
  final batches = ref.watch(downloadBatchesProvider);
  final working =
      active.values
          .where(
            (d) =>
                d.status == DownloadStatus.pending ||
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.error,
          )
          .toList();
  if (working.isEmpty) return null;

  final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
  final batchIds = working.map((d) => d.batchId).whereType<String>().toSet();
  final hasSingles = working.any((d) => d.batchId == null);

  if (working.length == 1) {
    final item = working.first;
    final downloading = item.status == DownloadStatus.downloading;
    return DownloadBannerSummary(
      title:
          downloading
              ? '${item.title} · ${(item.progress * 100).round()}%'
              : '${item.title} · ${l10n.downloadQueued}',
      subtitle: l10n.tapToOpenDownloads,
      action: DownloadBannerAction.cancelItem,
      targetId: item.videoId,
      progress: downloading ? item.progress : null,
    );
  }

  if (!hasSingles && batchIds.length == 1) {
    final batchId = batchIds.first;
    final batch = batches[batchId];
    final name = batch?.name ?? working.first.batchName ?? '';
    final total = batch?.total ?? working.first.batchTotal ?? working.length;
    final done = batch?.completed ?? 0;
    return DownloadBannerSummary(
      title: l10n.downloadingBatchProgress(name, done, total),
      subtitle: l10n.tapToOpenDownloads,
      action: DownloadBannerAction.cancelBatch,
      targetId: batchId,
    );
  }

  return DownloadBannerSummary(
    title: l10n.downloadsInProgress(working.length),
    subtitle: l10n.tapToOpenDownloads,
    action: DownloadBannerAction.cancelAll,
  );
});

enum DownloadsSort { newest, title, largest }

class DownloadsSortNotifier extends Notifier<DownloadsSort> {
  @override
  DownloadsSort build() => DownloadsSort.newest;

  void update(DownloadsSort value) => state = value;
}

final downloadsSortProvider =
    NotifierProvider<DownloadsSortNotifier, DownloadsSort>(
      DownloadsSortNotifier.new,
    );

// ── Notifier internals ────────────────────────────────────────────────────

class _DownloadRequest {
  final String videoId;
  final String title;
  final String artist;
  final String? artistsJson;
  final String? thumbnailUrl;
  final String? subdirectory;
  final bool isExplicit;
  final bool isVideo;
  final String? batchId;
  final String? batchName;
  final int? batchTotal;
  final String? collectionId;
  final String? collectionType;
  final String? collectionName;

  const _DownloadRequest({
    required this.videoId,
    required this.title,
    required this.artist,
    this.artistsJson,
    this.thumbnailUrl,
    this.subdirectory,
    this.isExplicit = false,
    this.isVideo = false,
    this.batchId,
    this.batchName,
    this.batchTotal,
    this.collectionId,
    this.collectionType,
    this.collectionName,
  });
}

/// Computes a smoothed transfer speed from progress ticks.
class _SpeedSampler {
  static const _recomputeInterval = Duration(milliseconds: 500);

  DateTime? _lastSampleAt;
  int _lastSampleBytes = 0;
  double? _speed;

  double? sample(int receivedBytes) {
    final now = DateTime.now();
    if (_lastSampleAt == null) {
      _lastSampleAt = now;
      _lastSampleBytes = receivedBytes;
      return _speed;
    }
    final elapsed = now.difference(_lastSampleAt!);
    if (elapsed < _recomputeInterval) return _speed;
    final deltaSeconds = elapsed.inMilliseconds / 1000;
    if (deltaSeconds > 0) {
      final instant = (receivedBytes - _lastSampleBytes) / deltaSeconds;
      _speed = _speed == null ? instant : _speed! * 0.6 + instant * 0.4;
    }
    _lastSampleAt = now;
    _lastSampleBytes = receivedBytes;
    return _speed;
  }
}

class DownloadsNotifier extends Notifier<Map<String, ActiveDownload>> {
  static const _uiUpdateInterval = Duration(milliseconds: 200);
  static const _notificationUpdateInterval = Duration(milliseconds: 500);

  final Map<String, _DownloadRequest> _requests = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Completer<void>> _completers = {};
  final Map<String, _SpeedSampler> _samplers = {};
  final Map<String, DateTime> _lastUiUpdate = {};
  final Map<String, int> _enqueueOrder = {};
  final Map<String, DownloadBatchProgress> _batches = {};
  int _nextOrder = 0;
  DateTime? _lastNotificationUpdate;
  Timer? _completionDismissTimer;

  /// Exposed for [downloadBatchesProvider] without duplicating mutable state.
  Map<String, DownloadBatchProgress> get batchProgress =>
      Map.unmodifiable(_batches);

  @override
  Map<String, ActiveDownload> build() {
    ref.onDispose(() {
      _completionDismissTimer?.cancel();
    });
    return {};
  }

  bool isDownloading(String videoId) => state.containsKey(videoId);

  bool isBatchActive(String batchId) {
    return state.values.any(
      (d) =>
          d.batchId == batchId &&
          (d.status == DownloadStatus.pending ||
              d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.error),
    );
  }

  /// Enqueues a download. The returned future completes when that item
  /// reaches a terminal state. Bulk callers should fire-and-forget so the
  /// whole collection enters the queue immediately.
  Future<void> startDownload({
    required String videoId,
    required String title,
    required String artist,
    String? artistsJson,
    String? thumbnailUrl,
    String? subdirectory,
    bool isExplicit = false,
    bool isVideo = false,
    String? batchId,
    String? batchName,
    int? batchTotal,
  }) {
    final existingCompleter = _completers[videoId];
    if (existingCompleter != null) return existingCompleter.future;

    final parsed = parseDownloadBatchId(batchId);
    final request = _DownloadRequest(
      videoId: videoId,
      title: title,
      artist: artist,
      artistsJson: artistsJson,
      thumbnailUrl: thumbnailUrl,
      subdirectory: subdirectory,
      isExplicit: isExplicit,
      isVideo: isVideo,
      batchId: batchId,
      batchName: batchName,
      batchTotal: batchTotal,
      collectionId: parsed?.collectionId,
      collectionType: parsed?.collectionType,
      collectionName: batchName,
    );
    _requests[videoId] = request;

    if (batchId != null && batchName != null && batchTotal != null) {
      final existing = _batches[batchId];
      _batches[batchId] = DownloadBatchProgress(
        id: batchId,
        name: batchName,
        total:
            existing == null
                ? batchTotal
                : (existing.total > batchTotal ? existing.total : batchTotal),
        completed: existing?.completed ?? 0,
      );
    }

    final completer = Completer<void>();
    _completers[videoId] = completer;
    _enqueueOrder[videoId] = _nextOrder++;

    state = {
      ...state,
      videoId: ActiveDownload(
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        batchId: batchId,
        batchName: batchName,
        batchTotal: batchTotal,
      ),
    };

    _pump();
    _syncNotification();
    return completer.future;
  }

  Future<void> cancelDownload(String videoId) async {
    final download = state[videoId];
    if (download == null) return;

    if (download.status == DownloadStatus.downloading) {
      final token = _cancelTokens[videoId];
      if (token != null) {
        token.cancel('Cancelled by user');
        return;
      }
    }
    _remove(videoId);
    _cleanupEmptyBatch(download.batchId);
    _pump();
    _syncNotification();
  }

  Future<void> cancelBatch(String batchId) async {
    final ids =
        state.entries
            .where(
              (e) =>
                  e.value.batchId == batchId &&
                  e.value.status != DownloadStatus.completed,
            )
            .map((e) => e.key)
            .toList();
    for (final id in ids) {
      await cancelDownload(id);
    }
    _batches.remove(batchId);
    _syncNotification();
  }

  Future<void> cancelAll() async {
    final ids =
        state.entries
            .where((e) => e.value.status != DownloadStatus.completed)
            .map((e) => e.key)
            .toList();
    for (final id in ids) {
      await cancelDownload(id);
    }
    _batches.clear();
    await _notifications.dismiss();
  }

  Future<void> deleteDownload(String videoId) async {
    if (state[videoId]?.status == DownloadStatus.downloading) {
      _cancelTokens[videoId]?.cancel('Deleted');
    }
    await ref.read(deleteDownloadUseCaseProvider).execute(videoId);
    if (state.containsKey(videoId)) {
      final batchId = state[videoId]?.batchId;
      _remove(videoId);
      _cleanupEmptyBatch(batchId);
      _pump();
      _syncNotification();
    }
  }

  Future<void> retry(String videoId) async {
    final request = _requests[videoId];
    if (request == null) return;
    if (state[videoId]?.status != DownloadStatus.error) return;

    state = Map.fromEntries(state.entries.where((e) => e.key != videoId));
    _samplers.remove(videoId);
    _lastUiUpdate.remove(videoId);
    _completers.remove(videoId);

    await startDownload(
      videoId: request.videoId,
      title: request.title,
      artist: request.artist,
      artistsJson: request.artistsJson,
      thumbnailUrl: request.thumbnailUrl,
      subdirectory: request.subdirectory,
      isExplicit: request.isExplicit,
      isVideo: request.isVideo,
      batchId: request.batchId,
      batchName: request.batchName,
      batchTotal: request.batchTotal,
    );
  }

  DownloadNotificationService get _notifications =>
      ref.read(downloadNotificationServiceProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(PlatformDispatcher.instance.locale);

  int get _activeCount =>
      state.values.where((d) => d.status == DownloadStatus.downloading).length;

  /// Promotes queued items (oldest first) while a concurrency slot is free.
  void _pump() {
    if (_activeCount >= kMaxConcurrentDownloads) return;
    final pending =
        state.values.where((d) => d.status == DownloadStatus.pending).toList()
          ..sort(
            (a, b) => (_enqueueOrder[a.videoId] ?? 0).compareTo(
              _enqueueOrder[b.videoId] ?? 0,
            ),
          );
    for (final download in pending) {
      if (_activeCount >= kMaxConcurrentDownloads) break;
      final request = _requests[download.videoId];
      if (request == null) continue;
      _run(request);
    }
  }

  Future<void> _run(_DownloadRequest request) async {
    final videoId = request.videoId;
    final cancelToken = CancelToken();
    _cancelTokens[videoId] = cancelToken;
    _samplers[videoId] = _SpeedSampler();

    _update(videoId, (d) => d.copyWith(status: DownloadStatus.downloading));
    _syncNotification(force: true);

    try {
      final useCase = ref.read(startDownloadUseCaseProvider);
      final settings = ref.read(settingsProvider);

      await useCase.execute(
        videoId: videoId,
        title: request.title,
        artist: request.artist,
        artistsJson: request.artistsJson,
        thumbnailUrl: request.thumbnailUrl,
        downloadOnlyOnWifi: settings.downloadOnlyOnWifi,
        downloadPath: settings.downloadPath,
        subdirectory: request.subdirectory,
        isExplicit: request.isExplicit,
        isVideo: request.isVideo,
        collectionId: request.collectionId,
        collectionType: request.collectionType,
        collectionName: request.collectionName,
        quality: settings.downloadQuality,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final speed = _samplers[videoId]?.sample(received);
          _updateProgress(videoId, received, total, speed);
        },
      );

      _finishSuccess(videoId);
    } on DownloadCancelledException {
      _finishCancelled(videoId);
    } catch (e) {
      _finishError(videoId, _mapError(e));
      dev.log('[Download] failed for $videoId: $e');
    }
  }

  void _updateProgress(String videoId, int received, int total, double? speed) {
    final now = DateTime.now();
    final last = _lastUiUpdate[videoId];
    if (last != null && now.difference(last) < _uiUpdateInterval) return;
    _lastUiUpdate[videoId] = now;
    _update(
      videoId,
      (d) => d.copyWith(
        receivedBytes: received,
        totalBytes: total,
        speedBytesPerSec: speed,
      ),
    );
    _syncNotification();
  }

  void _finishSuccess(String videoId) {
    final download = state[videoId];
    _cancelTokens.remove(videoId);
    _samplers.remove(videoId);
    _lastUiUpdate.remove(videoId);

    if (download != null) {
      _update(
        videoId,
        (d) => d.copyWith(
          status: DownloadStatus.completed,
          receivedBytes: d.totalBytes,
          clearSpeed: true,
        ),
      );
      _incrementBatchCompleted(download.batchId);
    }

    _completeItem(videoId);
    _pump();
    _syncNotification(force: true);

    Future.delayed(const Duration(seconds: 3), () {
      try {
        if (state[videoId]?.status == DownloadStatus.completed) {
          final batchId = state[videoId]?.batchId;
          _remove(videoId);
          _cleanupEmptyBatch(batchId);
          _syncNotification(force: true);
        }
      } catch (_) {}
    });
  }

  void _finishCancelled(String videoId) {
    final batchId = state[videoId]?.batchId;
    _remove(videoId);
    _cleanupEmptyBatch(batchId);
    _pump();
    _syncNotification(force: true);
  }

  void _finishError(String videoId, DownloadError error) {
    _cancelTokens.remove(videoId);
    _samplers.remove(videoId);
    _lastUiUpdate.remove(videoId);
    _update(
      videoId,
      (d) => d.copyWith(
        status: DownloadStatus.error,
        error: error,
        clearSpeed: true,
      ),
    );
    _completeItem(videoId);
    _pump();
    _syncNotification(force: true);
  }

  void _incrementBatchCompleted(String? batchId) {
    if (batchId == null) return;
    final batch = _batches[batchId];
    if (batch == null) return;
    _batches[batchId] = DownloadBatchProgress(
      id: batch.id,
      name: batch.name,
      total: batch.total,
      completed: batch.completed + 1,
    );
  }

  void _cleanupEmptyBatch(String? batchId) {
    if (batchId == null) return;
    final stillActive = state.values.any(
      (d) =>
          d.batchId == batchId &&
          (d.status == DownloadStatus.pending ||
              d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.error ||
              d.status == DownloadStatus.completed),
    );
    if (!stillActive) {
      _batches.remove(batchId);
    }
  }

  void _update(
    String videoId,
    ActiveDownload Function(ActiveDownload) transform,
  ) {
    final current = state[videoId];
    if (current == null) return;
    state = {...state, videoId: transform(current)};
  }

  void _remove(String videoId) {
    _requests.remove(videoId);
    _cancelTokens.remove(videoId);
    _samplers.remove(videoId);
    _lastUiUpdate.remove(videoId);
    _enqueueOrder.remove(videoId);
    if (state.containsKey(videoId)) {
      state = Map.fromEntries(state.entries.where((e) => e.key != videoId));
    }
    _completeItem(videoId);
  }

  void _completeItem(String videoId) {
    _completers.remove(videoId)?.complete();
  }

  DownloadError _mapError(Object error) {
    if (error is DownloadWifiRestrictionException) {
      return DownloadError.wifiRestricted;
    }
    if (error is DioException) return DownloadError.network;
    if (error is FileSystemException) return DownloadError.storage;
    return DownloadError.unknown;
  }

  List<ActiveDownload> get _working =>
      state.values
          .where(
            (d) =>
                d.status == DownloadStatus.pending ||
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.error,
          )
          .toList();

  Future<void> _syncNotification({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastNotificationUpdate != null &&
        now.difference(_lastNotificationUpdate!) <
            _notificationUpdateInterval) {
      return;
    }
    _lastNotificationUpdate = now;

    final working = _working;
    final l10n = _l10n;

    if (working.isEmpty) {
      final justCompleted =
          state.values
              .where((d) => d.status == DownloadStatus.completed)
              .toList();
      if (justCompleted.isEmpty && _batches.isEmpty) {
        _completionDismissTimer?.cancel();
        return;
      }

      final completedFromBatches = _batches.values.fold<int>(
        0,
        (sum, b) => sum + b.completed,
      );
      final totalDone =
          justCompleted.length > completedFromBatches
              ? justCompleted.length
              : completedFromBatches;

      try {
        if (totalDone <= 1 && justCompleted.isNotEmpty) {
          await _notifications.showCompleted(
            title: l10n.downloadComplete,
            body: l10n.songDownloaded(justCompleted.first.title),
          );
        } else if (totalDone > 0) {
          await _notifications.showCompleted(
            title: l10n.downloadComplete,
            body: l10n.songsDownloadedCount(totalDone),
          );
        }
      } catch (_) {}

      _completionDismissTimer?.cancel();
      _completionDismissTimer = Timer(const Duration(seconds: 4), () async {
        try {
          await _notifications.dismiss();
        } catch (_) {}
      });
      return;
    }

    _completionDismissTimer?.cancel();

    final batchIds = working.map((d) => d.batchId).whereType<String>().toSet();
    final hasSingles = working.any((d) => d.batchId == null);

    String body;
    int progress;
    int maxProgress;

    if (working.length == 1) {
      final item = working.first;
      body =
          item.status == DownloadStatus.downloading
              ? '${item.title} · ${(item.progress * 100).round()}%'
              : '${item.title} · ${l10n.downloadQueued}';
      progress = (item.progress * 100).round();
      maxProgress = 100;
    } else if (!hasSingles && batchIds.length == 1) {
      final batchId = batchIds.first;
      final batch = _batches[batchId];
      final name = batch?.name ?? working.first.batchName ?? '';
      final total = batch?.total ?? working.first.batchTotal ?? working.length;
      final done = batch?.completed ?? 0;
      body = l10n.downloadingBatchProgress(name, done, total);
      progress = done;
      maxProgress = total <= 0 ? 1 : total;
    } else {
      body = l10n.downloadsInProgress(working.length);
      final sessionTotal = state.length;
      final done =
          state.values
              .where((d) => d.status == DownloadStatus.completed)
              .length;
      progress = done;
      maxProgress = sessionTotal <= 0 ? working.length : sessionTotal;
    }

    try {
      await _notifications.showProgress(
        title: l10n.downloadInProgress,
        body: body,
        progress: progress,
        maxProgress: maxProgress,
      );
    } catch (_) {}
  }
}
