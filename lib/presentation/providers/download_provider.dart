import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/notification_utils.dart';
import '../../domain/models/library_models.dart';
import 'library_repository_provider.dart';
import 'settings_provider.dart';
import 'start_download_use_case_provider.dart';

// ── Download state models ──────────────────────────────────────────────────

enum DownloadStatus { pending, downloading, completed, error }

class ActiveDownload {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final DownloadStatus status;
  final double progress;
  final String? errorMessage;

  const ActiveDownload({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.status = DownloadStatus.downloading,
    this.progress = 0.0,
    this.errorMessage,
  });

  ActiveDownload copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return ActiveDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final allDownloadsProvider = FutureProvider<List<DownloadModel>>((ref) {
  return ref.watch(libraryRepositoryProvider).getAllDownloads();
});

final activeDownloadsProvider =
    NotifierProvider<DownloadsNotifier, Map<String, ActiveDownload>>(
      DownloadsNotifier.new,
    );

final downloadedIdsProvider = Provider<Set<String>>((ref) {
  final allDownloads = ref.watch(allDownloadsProvider);
  return allDownloads.asData?.value.map((d) => d.videoId).toSet() ?? {};
});

class DownloadsNotifier extends Notifier<Map<String, ActiveDownload>> {
  @override
  Map<String, ActiveDownload> build() => {};

  bool isDownloading(String videoId) => state.containsKey(videoId);

  Future<void> startDownload({
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    String? subdirectory,
    bool isExplicit = false,
  }) async {
    if (state.containsKey(videoId)) return;

    state = {
      ...state,
      videoId: ActiveDownload(
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
      ),
    };

    try {
      final useCase = ref.read(startDownloadUseCaseProvider);
      final settings = ref.read(settingsProvider);

      await useCase.execute(
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        downloadOnlyOnWifi: settings.downloadOnlyOnWifi,
        downloadPath: settings.downloadPath,
        subdirectory: subdirectory,
        isExplicit: isExplicit,
        onProgress: (progress) {
          state = {
            ...state,
            videoId: state[videoId]!.copyWith(progress: progress),
          };
        },
      );

      state = {
        ...state,
        videoId: state[videoId]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      };
      ref.invalidate(allDownloadsProvider);

      try {
        await flutterLocalNotificationsPlugin.show(
          id: videoId.hashCode,
          title: 'Download Complete',
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

      Future.delayed(const Duration(seconds: 3), () {
        if (state[videoId]?.status == DownloadStatus.completed) {
          state = Map.fromEntries(state.entries.where((e) => e.key != videoId));
        }
      });
    } catch (e) {
      state = {
        ...state,
        videoId: state[videoId]!.copyWith(
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        ),
      };
    }
  }

  Future<void> deleteDownload(String videoId) async {
    final repo = ref.read(libraryRepositoryProvider);
    final download = await repo.getDownload(videoId);
    await repo.deleteDownload(videoId);
    if (download?.localPath != null) {
      try {
        final file = File(download!.localPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    state = Map.fromEntries(state.entries.where((e) => e.key != videoId));
    ref.invalidate(allDownloadsProvider);
  }

  void dismiss(String videoId) {
    state = Map.fromEntries(state.entries.where((e) => e.key != videoId));
  }

  Future<void> retry({
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    bool isExplicit = false,
  }) async {
    state = Map.fromEntries(state.entries.where((e) => e.key != videoId));
    await startDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      isExplicit: isExplicit,
    );
  }
}
