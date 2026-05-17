import 'dart:convert';
import 'dart:io';

class UpdateCheckResult {
  final String latestVersion;
  final String changelog;
  final bool isNewer;

  const UpdateCheckResult({
    this.latestVersion = '',
    this.changelog = '',
    this.isNewer = false,
  });
}

class CheckForUpdatesUseCase {
  final String repoOwner;
  final String repoName;

  CheckForUpdatesUseCase({
    required this.repoOwner,
    required this.repoName,
  });

  Future<UpdateCheckResult> execute({
    required String currentVersion,
    int? lastCheckEpochMillis,
  }) async {
    if (lastCheckEpochMillis != null) {
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - lastCheckEpochMillis;
      if (elapsed < const Duration(hours: 24).inMilliseconds) {
        return const UpdateCheckResult();
      }
    }

    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
        ),
      );
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final latestTag = data['tag_name'] as String? ?? '';
      final changelog = data['body'] as String? ?? '';

      return UpdateCheckResult(
        latestVersion: latestTag,
        changelog: changelog,
        isNewer: latestTag.compareTo(currentVersion) > 0,
      );
    } catch (_) {
      return const UpdateCheckResult();
    }
  }
}
