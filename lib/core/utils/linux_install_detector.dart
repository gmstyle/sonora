import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/usecases/update/linux_asset_selection.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);
typedef FileExistsCheck = bool Function(String path);
typedef ReadFileSync = String? Function(String path);

/// Details about a natively installed Linux package (`.deb` or `.rpm`) that
/// supports in-app upgrades via `pkexec` + `/opt/sonora/sonora-updater`.
class LinuxInstallInfo {
  final LinuxPackageFormat format;
  final String arch;
  final String executablePath;
  final String updaterHelperPath;

  const LinuxInstallInfo({
    required this.format,
    required this.arch,
    required this.executablePath,
    required this.updaterHelperPath,
  });
}

/// Detects whether the running Linux binary was installed via a `.deb` or
/// `.rpm` package and can be upgraded in-place.
class LinuxInstallDetector {
  LinuxInstallDetector._();

  static final _dpkgOwnerPattern = RegExp(r'^sonora(:[^:]+)?:');

  static Future<LinuxInstallInfo?> detect({
    bool? isLinux,
    String? executablePath,
    Map<String, String>? environment,
    FileExistsCheck? fileExists,
    ReadFileSync? readFile,
    ProcessRunner? processRunner,
  }) async {
    if (!(isLinux ?? Platform.isLinux)) return null;

    final exists = fileExists ?? _defaultFileExists;
    final env = environment ?? Platform.environment;

    // Exclude sandboxed and immutable/read-only environments where in-place
    // dpkg/rpm upgrades cannot succeed without a system reboot or container rebuild.
    if (exists('/.flatpak-info')) return null;
    if ((env['SNAP'] ?? '').isNotEmpty) return null;
    if (exists('/run/ostree-booted')) return null;
    if (exists('/etc/NIXOS')) return null;

    final mounts = (readFile ?? _defaultReadFile)('/proc/mounts');
    if (mounts != null && _hasReadOnlySystemMount(mounts)) {
      return null;
    }

    final exePath = executablePath ?? Platform.resolvedExecutable;
    if (exePath.isEmpty) return null;

    final helperPath = p.join(p.dirname(exePath), 'sonora-updater');
    if (!exists(helperPath)) return null;
    if (!_hasExecutableInPath('pkexec', env, exists)) return null;

    final run = processRunner ?? Process.run;

    final unameRes = await _safeRun(run, 'uname', const ['-m']);
    if (unameRes == null || unameRes.exitCode != 0) return null;
    final arch = unameRes.stdout.toString().trim();
    if (arch.isEmpty) return null;

    final rpmRes = await _safeRun(run, 'rpm', [
      '-qf',
      '--qf',
      '%{NAME}\n',
      exePath,
    ]);
    if (rpmRes != null &&
        rpmRes.exitCode == 0 &&
        rpmRes.stdout.toString().trim() == 'sonora') {
      return LinuxInstallInfo(
        format: LinuxPackageFormat.rpm,
        arch: arch,
        executablePath: exePath,
        updaterHelperPath: helperPath,
      );
    }

    final dpkgRes = await _safeRun(run, 'dpkg', ['-S', exePath]);
    if (dpkgRes != null &&
        dpkgRes.exitCode == 0 &&
        _dpkgOwnerPattern.hasMatch(dpkgRes.stdout.toString().trim())) {
      final statusRes = await _safeRun(run, 'dpkg-query', const [
        '-W',
        r'-f=${Status}\n',
        'sonora',
      ]);
      if (statusRes != null &&
          statusRes.exitCode == 0 &&
          statusRes.stdout.toString().contains('install ok installed')) {
        return LinuxInstallInfo(
          format: LinuxPackageFormat.deb,
          arch: arch,
          executablePath: exePath,
          updaterHelperPath: helperPath,
        );
      }
    }

    return null;
  }

  static bool _hasExecutableInPath(
    String binary,
    Map<String, String> env,
    FileExistsCheck exists,
  ) {
    final pathEnv = env['PATH'];
    final dirs = (pathEnv != null && pathEnv.isNotEmpty)
        ? pathEnv.split(':')
        : const ['/usr/bin', '/bin'];
    for (final dir in dirs) {
      if (dir.isEmpty) continue;
      if (exists(p.join(dir, binary))) return true;
    }
    return false;
  }

  static bool _defaultFileExists(String path) => File(path).existsSync();

  static String? _defaultReadFile(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  static bool _hasReadOnlySystemMount(String mountsContent) {
    for (final line in mountsContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final fields = trimmed.split(RegExp(r'\s+'));
      if (fields.length < 4) continue;
      final mountPoint = fields[1];
      if (mountPoint != '/' && mountPoint != '/usr') continue;
      final options = fields[3].split(',');
      if (options.contains('ro')) return true;
    }
    return false;
  }

  static Future<ProcessResult?> _safeRun(
    ProcessRunner runner,
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await runner(executable, arguments);
    } on ProcessException {
      return null;
    }
  }
}
