import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/apk_installer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/platform_utils.dart';
import '../../../domain/usecases/update/check_for_updates_use_case.dart';
import 'check_for_updates_use_case_provider.dart';

enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  noUpdateAvailable,
  downloading,
  downloadComplete,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final UpdateCheckResult? result;
  final double progress;
  final String? downloadPath;
  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.result,
    this.progress = 0,
    this.downloadPath,
    this.errorMessage,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateCheckResult? result,
    double? progress,
    String? downloadPath,
    String? errorMessage,
  }) {
    return UpdateState(
      status: status ?? this.status,
      result: status == UpdateStatus.idle ? null : (result ?? this.result),
      progress: progress ?? this.progress,
      downloadPath: downloadPath ?? this.downloadPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  Future<void> checkForUpdate() async {
    state = const UpdateState(status: UpdateStatus.checking);

    try {
      final useCase = ref.read(checkForUpdatesUseCaseProvider);
      final info = await PackageInfo.fromPlatform();
      final currentVersion = 'v${info.version}+${info.buildNumber}';
      final result = await useCase.execute(currentVersion: currentVersion);

      if (result.isNewer) {
        state = UpdateState(
          status: UpdateStatus.updateAvailable,
          result: result,
        );
      } else {
        state = const UpdateState(status: UpdateStatus.noUpdateAvailable);
      }
    } catch (e) {
      state = UpdateState(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final result = state.result;
    if (result == null || result.releaseAssetUrl.isEmpty) {
      state = UpdateState(
        status: UpdateStatus.error,
        errorMessage: 'No APK asset found for this release',
      );
      return;
    }

    if (isAndroid) {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
        if (await Permission.requestInstallPackages.isDenied) {
          await openAppSettings();
          state = const UpdateState(status: UpdateStatus.idle);
          return;
        }
      }
    }

    state = const UpdateState(status: UpdateStatus.downloading, progress: 0);

    try {
      final useCase = ref.read(checkForUpdatesUseCaseProvider);
      final path = await useCase.downloadApk(
        result.releaseAssetUrl,
        result.releaseAssetName,
        onProgress: (progress) {
          state = UpdateState(
            status: UpdateStatus.downloading,
            progress: progress,
            result: result,
          );
        },
      );

      state = UpdateState(
        status: UpdateStatus.downloadComplete,
        downloadPath: path,
        result: result,
      );
    } catch (e) {
      state = UpdateState(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
        result: result,
      );
    }
  }

  Future<void> installApk() async {
    final path = state.downloadPath;
    if (path == null) return;

    try {
      await ApkInstaller.installApk(path);

      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      state = const UpdateState(status: UpdateStatus.idle);
    } catch (e) {
      state = UpdateState(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const UpdateState(status: UpdateStatus.idle);
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);
