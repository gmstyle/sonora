import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import 'linux_install_detector.dart';
import 'linux_tray_service.dart';

typedef PackageProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  ProcessStartMode mode,
});

enum LinuxInstallOutcome { installed, cancelled, noAuthAgent, failed }

class LinuxInstallResult {
  final LinuxInstallOutcome outcome;
  final int exitCode;
  final String stderr;

  const LinuxInstallResult({
    required this.outcome,
    required this.exitCode,
    this.stderr = '',
  });
}

/// Runs privileged Linux package upgrades via `pkexec` and relaunches the app
/// in the user's desktop session after the old instance has released its locks.
class LinuxPackageInstaller {
  static const _deletedExeSuffix = ' (deleted)';
  static const _relaunchWatcherScript = r'''
i=0
while kill -0 "$1" 2>/dev/null && [ "$i" -lt 25 ]; do sleep 0.1; i=$((i+1)); done
if kill -0 "$1" 2>/dev/null; then
  kill -TERM "$1" 2>/dev/null || true
  i=0
  while kill -0 "$1" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 0.1; i=$((i+1)); done
fi
if kill -0 "$1" 2>/dev/null; then
  kill -KILL "$1" 2>/dev/null || true
  i=0
  while kill -0 "$1" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 0.1; i=$((i+1)); done
fi
exec "$2"
''';

  final ProcessRunner? _processRunner;
  final PackageProcessStarter? _processStarter;
  final void Function()? _closeWindow;
  final void Function(int code)? _exitProcess;
  final int Function()? _currentPid;
  final Duration _shutdownTimeout;
  final Duration _exitFallbackDelay;
  final String? _systemTempPath;

  const LinuxPackageInstaller({
    this._processRunner,
    this._processStarter,
    this._closeWindow,
    this._exitProcess,
    this._currentPid,
    this._shutdownTimeout = const Duration(seconds: 3),
    this._exitFallbackDelay = const Duration(milliseconds: 500),
    this._systemTempPath,
  });

  Future<LinuxInstallResult> installPackage({
    required LinuxInstallInfo installInfo,
    required String packagePath,
  }) async {
    final runner = _processRunner ?? Process.run;
    try {
      final result = await runner('pkexec', [
        installInfo.updaterHelperPath,
        installInfo.format.name,
        packagePath,
      ]);
      final stderr = result.stderr.toString().trim();
      final outcome = switch (result.exitCode) {
        0 => LinuxInstallOutcome.installed,
        126 => LinuxInstallOutcome.cancelled,
        127 => LinuxInstallOutcome.noAuthAgent,
        _ => LinuxInstallOutcome.failed,
      };
      return LinuxInstallResult(
        outcome: outcome,
        exitCode: result.exitCode,
        stderr: stderr,
      );
    } on ProcessException catch (e) {
      return LinuxInstallResult(
        outcome: LinuxInstallOutcome.failed,
        exitCode: -1,
        stderr: e.message,
      );
    }
  }

  Future<void> cleanupDownload(String filePath) async {
    final tempRoot = p.normalize(_systemTempPath ?? Directory.systemTemp.path);
    final parentPath = p.normalize(p.dirname(filePath));
    final base = p.basename(parentPath);
    if (!base.startsWith('sonora-update-') ||
        !p.isWithin(tempRoot, parentPath)) {
      return;
    }

    try {
      final dir = Directory(parentPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Shuts down app resources, spawns a detached watcher that waits for the
  /// current PID to exit (freeing D-Bus unique name and Unix socket), then
  /// launches [executablePath] and terminates the current process.
  Future<void> relaunchApp({
    required String executablePath,
    required Future<void> Function() beforeExit,
  }) async {
    try {
      await beforeExit().timeout(_shutdownTimeout);
    } catch (e) {
      debugPrint('Linux relaunch pre-exit cleanup failed/timed out: $e');
    }

    final cleanExecutablePath = executablePath.endsWith(_deletedExeSuffix)
        ? executablePath.substring(
            0,
            executablePath.length - _deletedExeSuffix.length,
          )
        : executablePath;

    final starter = _processStarter ?? _defaultStartProcess;
    final pidValue = (_currentPid ?? _defaultCurrentPid)();

    await starter('/bin/sh', [
      '-c',
      _relaunchWatcherScript,
      '_',
      '$pidValue',
      cleanExecutablePath,
    ], mode: ProcessStartMode.detached);

    try {
      (_closeWindow ?? LinuxTrayService.closeWindowForQuit)();
    } catch (e) {
      debugPrint('Linux relaunch window close failed: $e');
    }
    Timer(_exitFallbackDelay, () {
      (_exitProcess ?? exit)(0);
    });
  }

  static Future<Process> _defaultStartProcess(
    String executable,
    List<String> arguments, {
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return Process.start(executable, arguments, mode: mode);
  }

  static int _defaultCurrentPid() => pid;
}
