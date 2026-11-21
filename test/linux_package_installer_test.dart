import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sonora/core/utils/linux_install_detector.dart';
import 'package:sonora/core/utils/linux_package_installer.dart';
import 'package:sonora/domain/usecases/update/linux_asset_selection.dart';

class _FakeProcess implements Process {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const rpmInfo = LinuxInstallInfo(
    format: LinuxPackageFormat.rpm,
    arch: 'x86_64',
    executablePath: '/opt/sonora/sonora',
    updaterHelperPath: '/opt/sonora/sonora-updater',
  );

  group('LinuxPackageInstaller.installPackage', () {
    test('passes separated args to pkexec and maps exit codes', () async {
      String? invokedCmd;
      List<String>? invokedArgs;

      Future<LinuxInstallResult> runWithCode(int code, {String stderr = ''}) {
        final installer = LinuxPackageInstaller(
          processRunner: (cmd, args) async {
            invokedCmd = cmd;
            invokedArgs = args;
            return ProcessResult(0, code, '', stderr);
          },
        );
        return installer.installPackage(
          installInfo: rpmInfo,
          packagePath: '/tmp/sonora-update-123/sonora.rpm',
        );
      }

      final ok = await runWithCode(0);
      expect(ok.outcome, LinuxInstallOutcome.installed);
      expect(invokedCmd, 'pkexec');
      expect(invokedArgs, [
        '/opt/sonora/sonora-updater',
        'rpm',
        '/tmp/sonora-update-123/sonora.rpm',
      ]);

      expect((await runWithCode(126)).outcome, LinuxInstallOutcome.cancelled);
      expect((await runWithCode(127)).outcome, LinuxInstallOutcome.noAuthAgent);
      final failed = await runWithCode(1, stderr: 'rpm error');
      expect(failed.outcome, LinuxInstallOutcome.failed);
      expect(failed.stderr, 'rpm error');
    });

    test('maps ProcessException to failed outcome', () async {
      final installer = LinuxPackageInstaller(
        processRunner: (_, _) => throw const ProcessException('pkexec', []),
      );
      final res = await installer.installPackage(
        installInfo: rpmInfo,
        packagePath: '/tmp/sonora-update-123/sonora.rpm',
      );
      expect(res.outcome, LinuxInstallOutcome.failed);
      expect(res.exitCode, -1);
    });
  });

  group('LinuxPackageInstaller.cleanupDownload', () {
    test('deletes sonora-update-* directory inside temp root only', () async {
      final root = await Directory.systemTemp.createTemp('sonora-test-root-');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final updateDir = Directory(p.join(root.path, 'sonora-update-abc'));
      await updateDir.create();
      final pkg = File(p.join(updateDir.path, 'sonora.rpm'));
      await pkg.writeAsString('pkg');

      final otherDir = Directory(p.join(root.path, 'unrelated-dir'));
      await otherDir.create();
      final keep = File(p.join(otherDir.path, 'keep.txt'));
      await keep.writeAsString('keep');

      final installer = LinuxPackageInstaller(systemTempPath: root.path);
      await installer.cleanupDownload(pkg.path);
      await installer.cleanupDownload(keep.path);

      expect(await updateDir.exists(), isFalse);
      expect(await otherDir.exists(), isTrue);
    });
  });

  group('LinuxPackageInstaller.relaunchApp', () {
    test(
      'orders shutdown before detached spawn, closes window, and triggers exit',
      () async {
        final events = <String>[];
        String? spawnedExec;
        List<String>? spawnedArgs;
        ProcessStartMode? spawnedMode;

        final installer = LinuxPackageInstaller(
          currentPid: () => 4242,
          exitFallbackDelay: const Duration(milliseconds: 10),
          processStarter: (exec, args, {mode = ProcessStartMode.normal}) async {
            events.add('spawn');
            spawnedExec = exec;
            spawnedArgs = args;
            spawnedMode = mode;
            return _FakeProcess();
          },
          closeWindow: () => events.add('closeWindow'),
          exitProcess: (code) => events.add('exit:$code'),
        );

        await installer.relaunchApp(
          executablePath: '/opt/sonora/sonora',
          beforeExit: () async => events.add('beforeExit'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(events, ['beforeExit', 'spawn', 'closeWindow', 'exit:0']);
        expect(spawnedExec, '/bin/sh');
        expect(spawnedMode, ProcessStartMode.detached);
        expect(spawnedArgs?[1], contains('kill -TERM'));
        expect(spawnedArgs?[1], contains('kill -KILL'));
        expect(spawnedArgs?.sublist(2), ['_', '4242', '/opt/sonora/sonora']);
      },
    );

    test(
      'proceeds to spawn and exit when beforeExit hangs or closeWindow throws',
      () async {
        final events = <String>[];
        List<String>? spawnedArgs;

        final installer = LinuxPackageInstaller(
          currentPid: () => 5150,
          shutdownTimeout: const Duration(milliseconds: 20),
          exitFallbackDelay: const Duration(milliseconds: 10),
          processStarter: (exec, args, {mode = ProcessStartMode.normal}) async {
            events.add('spawn');
            spawnedArgs = args;
            return _FakeProcess();
          },
          closeWindow: () {
            events.add('closeWindowThrows');
            throw StateError('window close failed');
          },
          exitProcess: (code) => events.add('exit:$code'),
        );

        await installer.relaunchApp(
          executablePath: '/opt/sonora/sonora (deleted)',
          beforeExit: () => Completer<void>().future,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(events, ['spawn', 'closeWindowThrows', 'exit:0']);
        expect(spawnedArgs?.sublist(2), ['_', '5150', '/opt/sonora/sonora']);
      },
    );
  });
}
