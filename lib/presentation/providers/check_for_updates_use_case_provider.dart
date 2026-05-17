import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/usecases/update/check_for_updates_use_case.dart';

final checkForUpdatesUseCaseProvider = Provider<CheckForUpdatesUseCase>((ref) {
  return CheckForUpdatesUseCase(
    repoOwner: kGitHubRepoOwner,
    repoName: kGitHubRepoName,
  );
});
