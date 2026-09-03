import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/notification_utils.dart';
import '../../domain/models/library_models.dart';
import '../../domain/usecases/download/download_exceptions.dart';
import '../../l10n/app_localizations.dart';
import 'delete_download_use_case_provider.dart';
import 'library_repository_provider.dart';
import 'settings_provider.dart';
import 'start_download_use_case_provider.dart';

// ── Download state models ──────────────────────────────────────────────────

enum DownloadStatus { pending, downloading, completed, error }

enum DownloadError { wifiRestricted, network, storage, unknown }

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
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final allDownloadsProvider = StreamProvider<List<DownloadModel>>((ref) {
  return ref.watch(libraryRepositoryProvider).watchCompletedDownloads();
});

final activeDownloadsProvider =
    NotifierProvider<DownloadsNotifier, Map<String, ActiveDownload>>(
      DownloadsNotifier.new,
    );

final downloadedIdsProvider = Provider<Set<String>>((ref) {
  final allDownloads = ref.watch(allDownloadsProvider);
  return allDownloads.asData?.value.map((d) => d.videoId).toSet() ?? {};
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
  final String? thumbnailUrl;
  final String? subdirectory;
  final bool isExplicit;
  final bool isVideo;

  const _DownloadRequest({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.subdirectory,
    this.isExplicit = false,
    this.isVideo = false,
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

  final Map<String, _DownloadRequest> _requests = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Completer<void>> _completers = {};
  final Map<String, _SpeedSampler> _samplers = {};
  final Map<String, DateTime> _lastUiUpdate = {};
  final Map<String, int> _enqueueOrder = {};
  int _nextOrder = 0;

  @override
  Map<String, ActiveDownload> build() => {};

  bool isDownloading(String videoId) => state.containsKey(videoId);

  /// Enqueues a download and completes when that item reaches a terminal
  /// state (completed, error or cancelled). Errors are never thrown to the
  /// caller: they are surfaced through [ActiveDownload.error] so a failing
  /// item does not abort bulk download loops.
  Future<void> startDownload({
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    String? subdirectory,
    bool isExplicit = false,
    bool isVideo = false,
  }) {
    final existingCompleter = _completers[videoId];
    if (existingCompleter != null) return existingCompleter.future;

    final request = _DownloadRequest(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      subdirectory: subdirectory,
      isExplicit: isExplicit,
      isVideo: isVideo,
    );
    _requests[videoId] = request;

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
      ),
    };

    _pump();
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
    _pump();
  }

  Future<void> deleteDownload(String videoId) async {
    if (state[videoId]?.status == DownloadStatus.downloading) {
      _cancelTokens[videoId]?.cancel('Deleted');
    }
    await ref.read(deleteDownloadUseCaseProvider).execute(videoId);
    if (state.containsKey(videoId)) {
      _remove(videoId);
      _pump();
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
      thumbnailUrl: request.thumbnailUrl,
      subdirectory: request.subdirectory,
      isExplicit: request.isExplicit,
      isVideo: request.isVideo,
    );
  }

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

    try {
      final useCase = ref.read(startDownloadUseCaseProvider);
      final settings = ref.read(settingsProvider);

      await useCase.execute(
        videoId: videoId,
        title: request.title,
        artist: request.artist,
        thumbnailUrl: request.thumbnailUrl,
        downloadOnlyOnWifi: settings.downloadOnlyOnWifi,
        downloadPath: settings.downloadPath,
        subdirectory: request.subdirectory,
        isExplicit: request.isExplicit,
        isVideo: request.isVideo,
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
      _showCompletionNotification(videoId, download.title);
    }

    _completeItem(videoId);
    _pump();

    Future.delayed(const Duration(seconds: 3), () {
      try {
        if (state[videoId]?.status == DownloadStatus.completed) {
          _remove(videoId);
        }
      } catch (_) {}
    });
  }

  void _finishCancelled(String videoId) {
    _remove(videoId);
    _pump();
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

  Future<void> _showCompletionNotification(String videoId, String title) async {
    try {
      final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
      await flutterLocalNotificationsPlugin.show(
        id: videoId.hashCode,
        title: l10n.downloadComplete,
        body: title,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'sonora_downloads',
            'Sonora Downloads',
            importance: Importance.defaultImportance,
          ),
          linux: LinuxNotificationDetails(defaultActionName: 'Open Sonora'),
        ),
      );
    } catch (_) {}
  }
}
