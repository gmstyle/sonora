import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/linux_install_detector.dart';
import '../../core/utils/linux_package_installer.dart';

/// Cleanly tears down Linux runtime resources (player, proxy, DB, socket, tray)
/// before a relaunch spawns the updated binary. Overridden in `main()`.
final linuxAppShutdownProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

/// Detects whether the current Linux executable belongs to a native `.deb` or
/// `.rpm` package that supports in-app upgrades.
final linuxInstallDetectorProvider =
    Provider<Future<LinuxInstallInfo?> Function()>(
      (ref) => LinuxInstallDetector.detect,
    );

/// Executes privileged Linux package upgrades and detached relaunches.
final linuxPackageInstallerProvider = Provider<LinuxPackageInstaller>(
  (ref) => const LinuxPackageInstaller(),
);
