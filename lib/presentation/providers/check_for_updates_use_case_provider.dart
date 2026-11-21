import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/device_abi.dart';
import '../../domain/usecases/update/check_for_updates_use_case.dart';
import 'linux_update_providers.dart';

final checkForUpdatesUseCaseProvider = Provider<CheckForUpdatesUseCase>((ref) {
  final detectLinux = ref.watch(linuxInstallDetectorProvider);
  return CheckForUpdatesUseCase(
    repoOwner: kGitHubRepoOwner,
    repoName: kGitHubRepoName,
    supportedAbis: DeviceAbi.getSupportedAbis,
    linuxInstallTarget: () async {
      final info = await detectLinux();
      if (info == null) return null;
      return (format: info.format, arch: info.arch);
    },
  );
});
