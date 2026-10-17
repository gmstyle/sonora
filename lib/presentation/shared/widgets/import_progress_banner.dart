import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/playlist_import_job_provider.dart';
import 'dock_progress_banner.dart';

/// Dock chip while a minimized playlist import / sync job is running.
class ImportProgressBanner extends ConsumerWidget {
  const ImportProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(playlistImportJobProvider);
    if (!job.showInDockBanner) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(playlistImportJobProvider.notifier);

    final title = switch (job.phase) {
      PlaylistImportJobPhase.awaitingReview => l10n.importMatchReviewTitle,
      PlaylistImportJobPhase.saving => l10n.importProgressSaving,
      PlaylistImportJobPhase.matching =>
        job.total > 0
            ? '${l10n.importProgressMatching} · ${job.current}/${job.total}'
            : l10n.importProgressMatching,
      _ => l10n.importing,
    };

    final subtitle =
        job.phase == PlaylistImportJobPhase.awaitingReview
            ? l10n.importJobTapToReview
            : (job.trackLabel ?? l10n.importJobTapToExpand);

    return DockProgressBanner(
      title: title,
      subtitle: subtitle,
      progress: job.progressValue,
      actionLabel: l10n.cancel,
      onAction: () => notifier.cancel(),
      onTap: () {
        notifier.expand();
        notifier.acknowledgeUiAttention();
        // Listener / host dialogs react to minimized == false + phase.
      },
    );
  }
}
