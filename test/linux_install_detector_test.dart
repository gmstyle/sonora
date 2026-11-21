import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/linux_install_detector.dart';
import 'package:sonora/domain/usecases/update/linux_asset_selection.dart';

ProcessResult _res(int exitCode, {String stdout = '', String stderr = ''}) =>
    ProcessResult(0, exitCode, stdout, stderr);

void main() {
  const exe = '/opt/sonora/sonora';
  const helper = '/opt/sonora/sonora-updater';
  const pkexec = '/usr/bin/pkexec';
  const defaultEnv = {'PATH': '/usr/bin'};

  bool defaultFiles(String path) => path == helper || path == pkexec;

  group('LinuxInstallDetector.detect', () {
    test('detects RPM package ownership', () async {
      final info = await LinuxInstallDetector.detect(
        isLinux: true,
        executablePath: exe,
        environment: defaultEnv,
        fileExists: defaultFiles,
        readFile: (_) => '/dev/sda1 / ext4 rw,relatime 0 0\n',
        processRunner: (cmd, args) async {
          if (cmd == 'uname') return _res(0, stdout: 'x86_64\n');
          if (cmd == 'rpm') return _res(0, stdout: 'sonora\n');
          return _res(1);
        },
      );

      expect(info, isNotNull);
      expect(info!.format, LinuxPackageFormat.rpm);
      expect(info.arch, 'x86_64');
      expect(info.executablePath, exe);
      expect(info.updaterHelperPath, helper);
    });

    test('detects DEB package ownership including multi-arch suffix', () async {
      final info = await LinuxInstallDetector.detect(
        isLinux: true,
        executablePath: exe,
        environment: defaultEnv,
        fileExists: defaultFiles,
        readFile: (_) => '/dev/nvme0n1p2 / ext4 rw 0 0\n',
        processRunner: (cmd, args) async {
          if (cmd == 'uname') return _res(0, stdout: 'x86_64\n');
          if (cmd == 'rpm') {
            throw const ProcessException('rpm', [], 'No such file');
          }
          if (cmd == 'dpkg') {
            return _res(0, stdout: 'sonora:amd64: /opt/sonora/sonora\n');
          }
          if (cmd == 'dpkg-query') {
            return _res(0, stdout: 'install ok installed\n');
          }
          return _res(1);
        },
      );

      expect(info, isNotNull);
      expect(info!.format, LinuxPackageFormat.deb);
      expect(info.arch, 'x86_64');
    });

    test('returns null off Linux', () async {
      final info = await LinuxInstallDetector.detect(isLinux: false);
      expect(info, isNull);
    });

    test('returns null for tarball or unowned executable', () async {
      final info = await LinuxInstallDetector.detect(
        isLinux: true,
        executablePath: exe,
        environment: defaultEnv,
        fileExists: defaultFiles,
        readFile: (_) => '/dev/sda1 / ext4 rw 0 0\n',
        processRunner: (cmd, args) async {
          if (cmd == 'uname') return _res(0, stdout: 'x86_64\n');
          return _res(1, stderr: 'not owned by any package');
        },
      );
      expect(info, isNull);
    });

    test('returns null when helper or pkexec is missing', () async {
      final noHelper = await LinuxInstallDetector.detect(
        isLinux: true,
        executablePath: exe,
        environment: defaultEnv,
        fileExists: (path) => path == pkexec,
        readFile: (_) => '/dev/sda1 / ext4 rw 0 0\n',
        processRunner: (_, _) async => _res(0),
      );
      expect(noHelper, isNull);

      final noPkexec = await LinuxInstallDetector.detect(
        isLinux: true,
        executablePath: exe,
        environment: defaultEnv,
        fileExists: (path) => path == helper,
        readFile: (_) => '/dev/sda1 / ext4 rw 0 0\n',
        processRunner: (_, _) async => _res(0),
      );
      expect(noPkexec, isNull);
    });

    test(
      'excludes Flatpak, Snap, ostree, NixOS, and read-only mounts',
      () async {
        Future<LinuxInstallInfo?> runWith({
          Map<String, String> env = defaultEnv,
          String? extraFile,
          String mounts = '/dev/sda1 / ext4 rw 0 0\n',
        }) {
          return LinuxInstallDetector.detect(
            isLinux: true,
            executablePath: exe,
            environment: env,
            fileExists: (path) => defaultFiles(path) || path == extraFile,
            readFile: (_) => mounts,
            processRunner: (cmd, _) async {
              if (cmd == 'uname') return _res(0, stdout: 'x86_64\n');
              if (cmd == 'rpm') return _res(0, stdout: 'sonora\n');
              return _res(1);
            },
          );
        }

        expect(await runWith(extraFile: '/.flatpak-info'), isNull);
        expect(
          await runWith(
            env: const {'PATH': '/usr/bin', 'SNAP': '/snap/sonora/1'},
          ),
          isNull,
        );
        expect(await runWith(extraFile: '/run/ostree-booted'), isNull);
        expect(await runWith(extraFile: '/etc/NIXOS'), isNull);
        expect(
          await runWith(mounts: 'overlay /usr overlay ro,relatime 0 0\n'),
          isNull,
        );
      },
    );

    test('returns null when dpkg-query status is not installed', () async {
      final info = await LinuxInstallDetector.detect(
        isLinux: true,
        executablePath: exe,
        environment: defaultEnv,
        fileExists: defaultFiles,
        readFile: (_) => '/dev/sda1 / ext4 rw 0 0\n',
        processRunner: (cmd, _) async {
          if (cmd == 'uname') return _res(0, stdout: 'x86_64\n');
          if (cmd == 'rpm') return _res(1);
          if (cmd == 'dpkg') {
            return _res(0, stdout: 'sonora: /opt/sonora/sonora\n');
          }
          if (cmd == 'dpkg-query') {
            return _res(0, stdout: 'deinstall ok config-files\n');
          }
          return _res(1);
        },
      );
      expect(info, isNull);
    });
  });
}
