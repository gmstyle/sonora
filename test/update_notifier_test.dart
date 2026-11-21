import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sonora/core/utils/linux_install_detector.dart';
import 'package:sonora/core/utils/linux_package_installer.dart';
import 'package:sonora/domain/usecases/update/check_for_updates_use_case.dart';
import 'package:sonora/domain/usecases/update/linux_asset_selection.dart';
import 'package:sonora/presentation/providers/check_for_updates_use_case_provider.dart';
import 'package:sonora/presentation/providers/linux_update_providers.dart';
import 'package:sonora/presentation/providers/update_notifier.dart';

class _FakeProcess implements Process {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _MockHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

class _StubCheckForUpdatesUseCase extends CheckForUpdatesUseCase {
  UpdateCheckResult? executeResult;
  bool throwChecksumMismatch = false;
  int downloadCalls = 0;
  late Directory tempRoot;

  _StubCheckForUpdatesUseCase({required this.tempRoot})
    : super(repoOwner: 'gmstyle', repoName: 'sonora');

  @override
  Future<UpdateCheckResult> execute({
    required String currentVersion,
    int? lastCheckEpochMillis,
  }) async {
    if (executeResult != null) return executeResult!;
    return super.execute(
      currentVersion: currentVersion,
      lastCheckEpochMillis: lastCheckEpochMillis,
    );
  }

  @override
  Future<String> downloadLinuxPackage(
    String url,
    String fileName, {
    String checksumAssetUrl = '',
    void Function(double progress)? onProgress,
    void Function()? onVerifying,
  }) async {
    downloadCalls++;
    onProgress?.call(0.5);
    onVerifying?.call();
    if (throwChecksumMismatch) {
      throw const UpdateChecksumException('bad hash');
    }
    final dir = await Directory(
      p.join(tempRoot.path, 'sonora-update-test-$downloadCalls'),
    ).create();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString('rpm-bytes');
    return file.path;
  }
}

void main() {
  const rpmInfo = LinuxInstallInfo(
    format: LinuxPackageFormat.rpm,
    arch: 'x86_64',
    executablePath: '/opt/sonora/sonora',
    updaterHelperPath: '/opt/sonora/sonora-updater',
  );

  const rpmAvailableResult = UpdateCheckResult(
    latestVersion: 'v2.0.2+80',
    changelog: '- **player**: Fix pause',
    isNewer: true,
    releaseAssetUrl: 'https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora-2.0.2-80.x86_64.rpm',
    releaseAssetName: 'sonora-2.0.2-80.x86_64.rpm',
    installTarget: UpdateInstallTarget.linuxRpm,
    checksumAssetUrl:
        'https://github.com/gmstyle/sonora/releases/download/v2.0.2/SHA256SUMS',
  );

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('sonora-notifier-test-');
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  ProviderContainer createContainer({
    required _StubCheckForUpdatesUseCase useCase,
    required LinuxPackageInstaller installer,
    Future<void> Function()? shutdown,
    Future<LinuxInstallInfo?> Function()? detector,
  }) {
    final container = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWithValue(() async => 'v2.0.1+79'),
        checkForUpdatesUseCaseProvider.overrideWithValue(useCase),
        linuxInstallDetectorProvider.overrideWithValue(
          detector ?? () async => rpmInfo,
        ),
        linuxPackageInstallerProvider.overrideWithValue(installer),
        linuxAppShutdownProvider.overrideWithValue(shutdown ?? () async {}),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('UpdateNotifier Linux flow', () {
    test('downloads, verifies, installs, shuts down, and relaunches', () async {
      final observedStatuses = <UpdateStatus>[];
      var shutdownCalled = false;
      var relaunched = false;
      var closedWindow = false;
      var exited = false;

      final useCase = _StubCheckForUpdatesUseCase(tempRoot: tempRoot)
        ..executeResult = rpmAvailableResult;

      final installer = LinuxPackageInstaller(
        systemTempPath: tempRoot.path,
        exitFallbackDelay: const Duration(milliseconds: 5),
        processRunner: (_, _) async => ProcessResult(0, 0, '', ''),
        processStarter: (_, _, {mode = ProcessStartMode.normal}) async {
          relaunched = true;
          return _FakeProcess();
        },
        closeWindow: () => closedWindow = true,
        exitProcess: (_) => exited = true,
      );

      final container = createContainer(
        useCase: useCase,
        installer: installer,
        shutdown: () async => shutdownCalled = true,
      );

      final sub = container.listen(
        updateProvider,
        (_, next) => observedStatuses.add(next.status),
      );
      addTearDown(sub.close);

      final notifier = container.read(updateProvider.notifier);
      await notifier.checkForUpdate();
      await notifier.downloadAndInstall();
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(observedStatuses, [
        UpdateStatus.checking,
        UpdateStatus.updateAvailable,
        UpdateStatus.downloading,
        UpdateStatus.downloading,
        UpdateStatus.verifying,
        UpdateStatus.downloadComplete,
        UpdateStatus.installing,
        UpdateStatus.restarting,
      ]);
      expect(shutdownCalled, isTrue);
      expect(relaunched, isTrue);
      expect(closedWindow, isTrue);
      expect(exited, isTrue);
      expect(
        await Directory(p.join(tempRoot.path, 'sonora-update-test-1')).exists(),
        isFalse,
      );
    });

    test(
      'preserves download on Polkit cancel (126) and allows retry',
      () async {
        var exitCode = 126;
        final useCase = _StubCheckForUpdatesUseCase(tempRoot: tempRoot)
          ..executeResult = rpmAvailableResult;

        final installer = LinuxPackageInstaller(
          systemTempPath: tempRoot.path,
          exitFallbackDelay: const Duration(milliseconds: 5),
          processRunner: (_, _) async => ProcessResult(0, exitCode, '', ''),
          processStarter: (_, _, {mode = ProcessStartMode.normal}) async =>
              _FakeProcess(),
          closeWindow: () {},
          exitProcess: (_) {},
        );

        final container = createContainer(
          useCase: useCase,
          installer: installer,
        );
        final notifier = container.read(updateProvider.notifier);
        await notifier.checkForUpdate();
        await notifier.downloadAndInstall();

        var state = container.read(updateProvider);
        expect(state.status, UpdateStatus.downloadComplete);
        expect(state.downloadPath, isNotNull);
        expect(await File(state.downloadPath!).exists(), isTrue);

        exitCode = 0;
        await notifier.installLinuxUpdate();
        await Future<void>.delayed(const Duration(milliseconds: 25));

        state = container.read(updateProvider);
        expect(state.status, UpdateStatus.restarting);
        expect(useCase.downloadCalls, 1);
      },
    );

    test(
      're-downloads instead of calling pkexec when temp file disappeared',
      () async {
        var exitCode = 126;
        var pkexecCalls = 0;
        final useCase = _StubCheckForUpdatesUseCase(tempRoot: tempRoot)
          ..executeResult = rpmAvailableResult;

        final installer = LinuxPackageInstaller(
          systemTempPath: tempRoot.path,
          exitFallbackDelay: const Duration(milliseconds: 5),
          processRunner: (_, _) async {
            pkexecCalls++;
            return ProcessResult(0, exitCode, '', '');
          },
          processStarter: (_, _, {mode = ProcessStartMode.normal}) async =>
              _FakeProcess(),
          closeWindow: () {},
          exitProcess: (_) {},
        );

        final container = createContainer(
          useCase: useCase,
          installer: installer,
        );
        final notifier = container.read(updateProvider.notifier);
        await notifier.checkForUpdate();
        await notifier.downloadAndInstall();

        final firstPath = container.read(updateProvider).downloadPath!;
        await File(firstPath).delete();

        exitCode = 0;
        await notifier.installLinuxUpdate();
        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(useCase.downloadCalls, 2);
        expect(pkexecCalls, 2);
        expect(container.read(updateProvider).status, UpdateStatus.restarting);
      },
    );

    test(
      'transitions to error if relaunchApp throws after installation',
      () async {
        final useCase = _StubCheckForUpdatesUseCase(tempRoot: tempRoot)
          ..executeResult = rpmAvailableResult;

        final installer = LinuxPackageInstaller(
          systemTempPath: tempRoot.path,
          processRunner: (_, _) async => ProcessResult(0, 0, '', ''),
          processStarter: (_, _, {mode = ProcessStartMode.normal}) async {
            throw const ProcessException('/bin/sh', []);
          },
          closeWindow: () {},
          exitProcess: (_) {},
        );

        final container = createContainer(
          useCase: useCase,
          installer: installer,
        );
        final notifier = container.read(updateProvider.notifier);
        await notifier.checkForUpdate();
        await notifier.downloadAndInstall();

        final state = container.read(updateProvider);
        expect(state.status, UpdateStatus.error);
        expect(state.errorKind, UpdateErrorKind.installFailed);
      },
    );

    test('maps checksum mismatch and Polkit missing agent errors', () async {
      final useCase = _StubCheckForUpdatesUseCase(tempRoot: tempRoot)
        ..executeResult = rpmAvailableResult
        ..throwChecksumMismatch = true;

      final installer = LinuxPackageInstaller(
        systemTempPath: tempRoot.path,
        processRunner: (_, _) async =>
            ProcessResult(0, 127, '', 'No polkit agent'),
      );

      final container = createContainer(useCase: useCase, installer: installer);
      final notifier = container.read(updateProvider.notifier);

      await notifier.checkForUpdate();
      await notifier.downloadAndInstall();
      expect(container.read(updateProvider).status, UpdateStatus.error);
      expect(
        container.read(updateProvider).errorKind,
        UpdateErrorKind.checksumMismatch,
      );

      useCase.throwChecksumMismatch = false;
      await notifier.checkForUpdate();
      await notifier.downloadAndInstall();
      expect(container.read(updateProvider).status, UpdateStatus.error);
      expect(
        container.read(updateProvider).errorKind,
        UpdateErrorKind.noPolkitAgent,
      );

      final path = container.read(updateProvider).downloadPath;
      expect(path, isNotNull);
      notifier.reset();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await File(path!).exists(), isFalse);
    });
  });

  group('CheckForUpdatesUseCase Linux integration', () {
    test('selects Linux RPM + SHA256SUMS or manual, and skips detector when up to date', () async {
      const releaseJson = '''
{
  "tag_name": "v2.0.2+80",
  "body": "### Features\\n- **update**: Linux support",
  "assets": [
    {
      "name": "sonora-2.0.2-80.x86_64.rpm",
      "browser_download_url": "https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora-2.0.2-80.x86_64.rpm"
    },
    {
      "name": "SHA256SUMS",
      "browser_download_url": "https://github.com/gmstyle/sonora/releases/download/v2.0.2/SHA256SUMS"
    }
  ]
}
''';

      final rpmUseCase = CheckForUpdatesUseCase(
        repoOwner: 'gmstyle',
        repoName: 'sonora',
        hostPlatform: UpdateHostPlatform.linux,
        linuxInstallTarget: () async =>
            (format: LinuxPackageFormat.rpm, arch: 'x86_64'),
        fetchJson: (_) async => releaseJson,
      );
      final rpmRes = await rpmUseCase.execute(currentVersion: 'v2.0.1+79');
      expect(rpmRes.isNewer, isTrue);
      expect(rpmRes.installTarget, UpdateInstallTarget.linuxRpm);
      expect(rpmRes.releaseAssetName, 'sonora-2.0.2-80.x86_64.rpm');
      expect(rpmRes.checksumAssetUrl, endsWith('/SHA256SUMS'));

      final manualUseCase = CheckForUpdatesUseCase(
        repoOwner: 'gmstyle',
        repoName: 'sonora',
        hostPlatform: UpdateHostPlatform.linux,
        linuxInstallTarget: () async => null,
        fetchJson: (_) async => releaseJson,
      );
      final manualRes = await manualUseCase.execute(
        currentVersion: 'v2.0.1+79',
      );
      expect(manualRes.isNewer, isTrue);
      expect(manualRes.installTarget, UpdateInstallTarget.manual);
      expect(manualRes.releaseAssetUrl, isEmpty);

      var detectorCalled = false;
      final upToDateUseCase = CheckForUpdatesUseCase(
        repoOwner: 'gmstyle',
        repoName: 'sonora',
        hostPlatform: UpdateHostPlatform.linux,
        linuxInstallTarget: () async {
          detectorCalled = true;
          return (format: LinuxPackageFormat.rpm, arch: 'x86_64');
        },
        fetchJson: (_) async => releaseJson,
      );
      final upToDateRes = await upToDateUseCase.execute(
        currentVersion: 'v2.0.2+80',
      );
      expect(upToDateRes.isNewer, isFalse);
      expect(detectorCalled, isFalse);
    });

    test(
      'downloadLinuxPackage verifies SHA-256 and cleans up on errors',
      () async {
        final pkgBytes = utf8.encode('fake-rpm-payload');
        final validHash = sha256.convert(pkgBytes).toString();
        var sumsBody = '$validHash  sonora-2.0.2-80.x86_64.rpm\n';
        var verifyingCalled = false;

        Dio mockDio() {
          final dio = Dio();
          dio.httpClientAdapter = _MockHttpAdapter((options) async {
            if (options.uri.path.endsWith('SHA256SUMS')) {
              return ResponseBody.fromString(sumsBody, 200);
            }
            return ResponseBody.fromBytes(
              pkgBytes,
              200,
              headers: {
                Headers.contentLengthHeader: ['${pkgBytes.length}'],
              },
            );
          });
          return dio;
        }

        final useCase = CheckForUpdatesUseCase(
          repoOwner: 'gmstyle',
          repoName: 'sonora',
          dioFactory: mockDio,
        );

        final downloadedPath = await useCase.downloadLinuxPackage(
          'https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora-2.0.2-80.x86_64.rpm',
          'sonora-2.0.2-80.x86_64.rpm',
          checksumAssetUrl: 'https://github.com/gmstyle/sonora/releases/download/v2.0.2/SHA256SUMS',
          onVerifying: () => verifyingCalled = true,
        );
        addTearDown(() async {
          final dir = Directory(p.dirname(downloadedPath));
          if (await dir.exists()) await dir.delete(recursive: true);
        });

        expect(verifyingCalled, isTrue);
        expect(await File(downloadedPath).readAsBytes(), pkgBytes);

        Set<String> listUpdateTempDirs() => Directory.systemTemp
            .listSync()
            .where((e) => p.basename(e.path).startsWith('sonora-update-'))
            .map((e) => e.path)
            .toSet();

        final beforeMismatch = listUpdateTempDirs();
        sumsBody = '${'0' * 64}  sonora-2.0.2-80.x86_64.rpm\n';
        await expectLater(
          useCase.downloadLinuxPackage(
            'https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora-2.0.2-80.x86_64.rpm',
            'sonora-2.0.2-80.x86_64.rpm',
            checksumAssetUrl: 'https://github.com/gmstyle/sonora/releases/download/v2.0.2/SHA256SUMS',
          ),
          throwsA(isA<UpdateChecksumException>()),
        );
        expect(listUpdateTempDirs().difference(beforeMismatch), isEmpty);

        final beforeMissing = listUpdateTempDirs();
        sumsBody = '${'0' * 64}  other-file.rpm\n';
        await expectLater(
          useCase.downloadLinuxPackage(
            'https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora-2.0.2-80.x86_64.rpm',
            'sonora-2.0.2-80.x86_64.rpm',
            checksumAssetUrl: 'https://github.com/gmstyle/sonora/releases/download/v2.0.2/SHA256SUMS',
          ),
          throwsA(isA<UpdateChecksumException>()),
        );
        expect(listUpdateTempDirs().difference(beforeMissing), isEmpty);

        await expectLater(
          useCase.downloadLinuxPackage(
            'https://evil.example.com/sonora.rpm',
            'sonora.rpm',
          ),
          throwsArgumentError,
        );
        await expectLater(
          useCase.downloadLinuxPackage(
            'https://github.com/gmstyle/sonora/releases/download/v2.0.2/sonora.txt',
            'sonora.txt',
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
