import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../domain/usecases/update/check_for_updates_use_case.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/update_notifier.dart';
import 'release_notes_view.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key});

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  String _localVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await ref.read(appVersionProvider)();
    if (mounted) {
      setState(() {
        _localVersion = version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(updateProvider.notifier);

    final isBusy =
        state.status == UpdateStatus.checking ||
        state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.verifying ||
        state.status == UpdateStatus.installing ||
        state.status == UpdateStatus.restarting;

    return PopScope(
      canPop: !isBusy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) notifier.reset();
      },
      child: AlertDialog(
        title: _buildTitle(state, l10n),
        content: _buildContent(context, state, l10n),
        actions: _buildActions(context, state, l10n, notifier, isOffline),
      ),
    );
  }

  Widget _buildTitle(UpdateState state, AppLocalizations l10n) {
    return switch (state.status) {
      UpdateStatus.checking => Text(l10n.checkingForUpdates),
      UpdateStatus.downloading => Text(l10n.downloadingUpdate),
      UpdateStatus.verifying => Text(l10n.verifyingUpdate),
      UpdateStatus.installing => Text(l10n.installingUpdate),
      UpdateStatus.restarting => Text(l10n.restartingApp),
      UpdateStatus.downloadComplete => Text(l10n.updateAvailable),
      UpdateStatus.updateAvailable => Text(l10n.updateAvailable),
      UpdateStatus.noUpdateAvailable => Text(l10n.upToDate),
      UpdateStatus.error => Text(l10n.error),
      UpdateStatus.idle => const SizedBox.shrink(),
    };
  }

  Widget _buildContent(
    BuildContext context,
    UpdateState state,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    switch (state.status) {
      case UpdateStatus.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );

      case UpdateStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
            ),
            if (state.progress > 0) ...[
              const SizedBox(height: 12),
              Text('${(state.progress * 100).toStringAsFixed(0)}%'),
            ],
          ],
        );

      case UpdateStatus.verifying:
        return const LinearProgressIndicator();

      case UpdateStatus.installing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              l10n.installingUpdateAuthHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case UpdateStatus.restarting:
        return const LinearProgressIndicator();

      case UpdateStatus.downloadComplete:
        return Text(l10n.downloadComplete);

      case UpdateStatus.updateAvailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_localVersion.isNotEmpty)
              Text(l10n.currentVersion(_localVersion)),
            Text(l10n.latestVersion(state.result?.latestVersion ?? '')),
            if (state.result?.changelog.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              ReleaseNotesView(changelog: state.result!.changelog),
            ],
          ],
        );

      case UpdateStatus.noUpdateAvailable:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_localVersion.isNotEmpty)
              Text(l10n.currentVersion(_localVersion)),
          ],
        );

      case UpdateStatus.error:
        return Text(_errorText(state, l10n));

      case UpdateStatus.idle:
        return const SizedBox.shrink();
    }
  }

  String _errorText(UpdateState state, AppLocalizations l10n) {
    final localized = switch (state.errorKind) {
      UpdateErrorKind.checksumMismatch => l10n.updateChecksumFailed,
      UpdateErrorKind.noPolkitAgent => l10n.updateNoAuthAgent,
      UpdateErrorKind.installFailed => l10n.updateInstallFailed,
      _ => l10n.unknownError,
    };
    if (kDebugMode &&
        state.errorMessage != null &&
        state.errorMessage!.isNotEmpty) {
      return '$localized\n\n${state.errorMessage}';
    }
    return localized;
  }

  void _close(BuildContext context, UpdateNotifier notifier) {
    notifier.reset();
    Navigator.pop(context);
  }

  void _openReleases(BuildContext context, UpdateNotifier notifier) {
    _close(context, notifier);
    launchUrl(
      Uri.parse('$kGitHubRepoUrl/releases/latest'),
      mode: LaunchMode.externalApplication,
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    UpdateState state,
    AppLocalizations l10n,
    UpdateNotifier notifier,
    bool isOffline,
  ) {
    final target = state.result?.installTarget ?? UpdateInstallTarget.manual;
    final isLinuxTarget =
        target == UpdateInstallTarget.linuxDeb ||
        target == UpdateInstallTarget.linuxRpm;

    switch (state.status) {
      case UpdateStatus.checking:
      case UpdateStatus.downloading:
      case UpdateStatus.verifying:
      case UpdateStatus.installing:
      case UpdateStatus.restarting:
        return const [];

      case UpdateStatus.downloadComplete:
        return [
          TextButton(
            onPressed: () => _close(context, notifier),
            child: Text(l10n.close),
          ),
          FilledButton.icon(
            onPressed: isLinuxTarget
                ? () => notifier.installLinuxUpdate()
                : () => notifier.installApk(),
            icon: Icon(
              isLinuxTarget ? LucideIcons.download : LucideIcons.smartphone,
            ),
            label: Text(l10n.installUpdate),
          ),
        ];

      case UpdateStatus.updateAvailable:
        return [
          TextButton(
            onPressed: () => _close(context, notifier),
            child: Text(l10n.close),
          ),
          if (target == UpdateInstallTarget.manual)
            FilledButton.icon(
              onPressed: isOffline
                  ? null
                  : () => _openReleases(context, notifier),
              icon: const Icon(LucideIcons.externalLink),
              label: Text(l10n.downloadUpdate),
            )
          else
            FilledButton.icon(
              onPressed: isOffline ? null : () => notifier.downloadAndInstall(),
              icon: const Icon(LucideIcons.download),
              label: Text(l10n.downloadUpdate),
            ),
        ];

      case UpdateStatus.noUpdateAvailable:
        return [
          FilledButton(
            onPressed: () => _close(context, notifier),
            child: Text(l10n.close),
          ),
        ];

      case UpdateStatus.error:
        final canRetryLocalInstall =
            isLinuxTarget &&
            state.downloadPath != null &&
            (state.errorKind == UpdateErrorKind.installFailed ||
                state.errorKind == UpdateErrorKind.noPolkitAgent);
        final showRetry =
            state.result?.isNewer == true &&
            (canRetryLocalInstall || target != UpdateInstallTarget.manual);

        return [
          TextButton(
            onPressed: () => _close(context, notifier),
            child: Text(l10n.close),
          ),
          if (isLinux || isLinuxTarget)
            TextButton.icon(
              onPressed: isOffline
                  ? null
                  : () => _openReleases(context, notifier),
              icon: const Icon(LucideIcons.externalLink),
              label: Text(l10n.openGitHubReleases),
            ),
          if (showRetry)
            FilledButton.icon(
              onPressed: canRetryLocalInstall
                  ? () => notifier.installLinuxUpdate()
                  : (isOffline ? null : () => notifier.downloadAndInstall()),
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(l10n.retry),
            ),
        ];

      case UpdateStatus.idle:
        return const [];
    }
  }
}
