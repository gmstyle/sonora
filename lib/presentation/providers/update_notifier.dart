import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/apk_installer.dart';
import '../../core/utils/linux_package_installer.dart';
import '../../core/utils/platform_utils.dart';
import '../../domain/usecases/update/check_for_updates_use_case.dart';
import 'check_for_updates_use_case_provider.dart';
import 'linux_update_providers.dart';

/// Reads the running application version string in `vX.Y.Z+B` format.
final appVersionProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version}+${info.buildNumber}';
  };
});

enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  noUpdateAvailable,
  downloading,
  verifying,
  downloadComplete,
  installing,
  restarting,
  error,
}

enum UpdateErrorKind {
  generic,
  noAsset,
  checksumMismatch,
  noPolkitAgent,
  installFailed,
}

class UpdateState {
  final UpdateStatus status;
  final UpdateCheckResult? result;
  final double progress;
  final String? downloadPath;
  final String? errorMessage;
  final UpdateErrorKind? errorKind;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.result,
    this.progress = 0,
    this.downloadPath,
    this.errorMessage,
    this.errorKind,
  });
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  Future<void> checkForUpdate() async {
    final previousPath = state.downloadPath;
    if (previousPath != null) {
      unawaited(
        ref.read(linuxPackageInstallerProvider).cleanupDownload(previousPath),
      );
    }

    state = const UpdateState(status: UpdateStatus.checking);

    try {
      final useCase = ref.read(checkForUpdatesUseCaseProvider);
      final currentVersion = await ref.read(appVersionProvider)();
      final result = await useCase.execute(currentVersion: currentVersion);
      if (!ref.mounted) return;

      if (result.isNewer) {
        state = UpdateState(
          status: UpdateStatus.updateAvailable,
          result: result,
        );
      } else {
        state = const UpdateState(status: UpdateStatus.noUpdateAvailable);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (!ref.mounted) return;
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.generic,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final result = state.result;
    if (result == null ||
        result.releaseAssetUrl.isEmpty ||
        result.installTarget == UpdateInstallTarget.manual) {
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.noAsset,
        errorMessage: 'No update package found for this release',
        result: result,
      );
      return;
    }

    if (result.installTarget == UpdateInstallTarget.androidApk) {
      await _downloadAndroidApk(result);
      return;
    }

    await _downloadAndInstallLinux(result);
  }

  Future<void> _downloadAndroidApk(UpdateCheckResult result) async {
    if (isAndroid) {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
        if (await Permission.requestInstallPackages.isDenied) {
          await openAppSettings();
          if (!ref.mounted) return;
          state = const UpdateState(status: UpdateStatus.idle);
          return;
        }
      }
    }

    if (!ref.mounted) return;
    state = UpdateState(
      status: UpdateStatus.downloading,
      progress: 0,
      result: result,
    );

    try {
      final useCase = ref.read(checkForUpdatesUseCaseProvider);
      final path = await useCase.downloadApk(
        result.releaseAssetUrl,
        result.releaseAssetName,
        onProgress: (progress) {
          if (!ref.mounted) return;
          state = UpdateState(
            status: UpdateStatus.downloading,
            progress: progress,
            result: result,
          );
        },
      );
      if (!ref.mounted) return;

      state = UpdateState(
        status: UpdateStatus.downloadComplete,
        downloadPath: path,
        result: result,
      );
    } catch (e) {
      debugPrint('APK download failed: $e');
      if (!ref.mounted) return;
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.generic,
        errorMessage: e.toString(),
        result: result,
      );
    }
  }

  Future<void> _downloadAndInstallLinux(UpdateCheckResult result) async {
    final installer = ref.read(linuxPackageInstallerProvider);
    final previousPath = state.downloadPath;
    if (previousPath != null) {
      await installer.cleanupDownload(previousPath);
    }
    if (!ref.mounted) return;

    state = UpdateState(
      status: UpdateStatus.downloading,
      progress: 0,
      result: result,
    );

    try {
      final useCase = ref.read(checkForUpdatesUseCaseProvider);
      final path = await useCase.downloadLinuxPackage(
        result.releaseAssetUrl,
        result.releaseAssetName,
        checksumAssetUrl: result.checksumAssetUrl,
        onProgress: (progress) {
          if (!ref.mounted) return;
          state = UpdateState(
            status: UpdateStatus.downloading,
            progress: progress,
            result: result,
          );
        },
        onVerifying: () {
          if (!ref.mounted) return;
          state = UpdateState(status: UpdateStatus.verifying, result: result);
        },
      );
      if (!ref.mounted) return;

      state = UpdateState(
        status: UpdateStatus.downloadComplete,
        downloadPath: path,
        result: result,
      );
      await installLinuxUpdate();
    } on UpdateChecksumException catch (e) {
      debugPrint('Linux update checksum verification failed: $e');
      if (!ref.mounted) return;
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.checksumMismatch,
        errorMessage: e.message,
        result: result,
      );
    } catch (e) {
      debugPrint('Linux update download failed: $e');
      if (!ref.mounted) return;
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.generic,
        errorMessage: e.toString(),
        result: result,
      );
    }
  }

  Future<void> installLinuxUpdate() async {
    final path = state.downloadPath;
    final result = state.result;
    if (path == null || result == null) return;

    if (!File(path).existsSync()) {
      await _downloadAndInstallLinux(result);
      return;
    }

    final installer = ref.read(linuxPackageInstallerProvider);
    final installInfo = await ref.read(linuxInstallDetectorProvider)();
    if (!ref.mounted) return;

    if (installInfo == null) {
      await installer.cleanupDownload(path);
      if (!ref.mounted) return;
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.installFailed,
        errorMessage: 'Native Linux package installation is unavailable',
        result: result,
      );
      return;
    }

    state = UpdateState(
      status: UpdateStatus.installing,
      downloadPath: path,
      result: result,
    );

    final installResult = await installer.installPackage(
      installInfo: installInfo,
      packagePath: path,
    );
    if (!ref.mounted) return;

    switch (installResult.outcome) {
      case LinuxInstallOutcome.installed:
        await installer.cleanupDownload(path);
        if (!ref.mounted) return;
        state = UpdateState(status: UpdateStatus.restarting, result: result);
        try {
          final beforeExit = ref.read(linuxAppShutdownProvider);
          await installer.relaunchApp(
            executablePath: installInfo.executablePath,
            beforeExit: beforeExit,
          );
        } catch (e) {
          debugPrint('Linux app relaunch failed: $e');
          if (!ref.mounted) return;
          state = UpdateState(
            status: UpdateStatus.error,
            errorKind: UpdateErrorKind.installFailed,
            errorMessage: e.toString(),
            result: result,
          );
        }
      case LinuxInstallOutcome.cancelled:
        state = UpdateState(
          status: UpdateStatus.downloadComplete,
          downloadPath: path,
          result: result,
        );
      case LinuxInstallOutcome.noAuthAgent:
        debugPrint(
          'Polkit authentication agent unavailable '
          '(exit ${installResult.exitCode}): ${installResult.stderr}',
        );
        state = UpdateState(
          status: UpdateStatus.error,
          errorKind: UpdateErrorKind.noPolkitAgent,
          errorMessage: installResult.stderr.isNotEmpty
              ? installResult.stderr
              : 'Polkit agent not found (exit ${installResult.exitCode})',
          downloadPath: path,
          result: result,
        );
      case LinuxInstallOutcome.failed:
        debugPrint(
          'Linux package install failed '
          '(exit ${installResult.exitCode}): ${installResult.stderr}',
        );
        state = UpdateState(
          status: UpdateStatus.error,
          errorKind: UpdateErrorKind.installFailed,
          errorMessage: installResult.stderr.isNotEmpty
              ? installResult.stderr
              : 'Installer exited with code ${installResult.exitCode}',
          downloadPath: path,
          result: result,
        );
    }
  }

  Future<void> installApk() async {
    final path = state.downloadPath;
    if (path == null) return;

    try {
      await ApkInstaller.installApk(path);
      if (!ref.mounted) return;
      state = const UpdateState(status: UpdateStatus.idle);
    } catch (e) {
      debugPrint('APK install failed: $e');
      if (!ref.mounted) return;
      state = UpdateState(
        status: UpdateStatus.error,
        errorKind: UpdateErrorKind.installFailed,
        errorMessage: e.toString(),
        result: state.result,
      );
    }
  }

  void reset() {
    final path = state.downloadPath;
    if (path != null) {
      unawaited(ref.read(linuxPackageInstallerProvider).cleanupDownload(path));
    }
    state = const UpdateState(status: UpdateStatus.idle);
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);
