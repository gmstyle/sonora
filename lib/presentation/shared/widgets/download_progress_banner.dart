import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import 'dock_progress_banner.dart';

/// Persistent progress chip above the mini-player while downloads are active.
/// Hidden on the Downloads tab (list already shows progress there).
class DownloadProgressBanner extends ConsumerWidget {
  const DownloadProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/downloads')) {
      return const SizedBox.shrink();
    }

    final summary = ref.watch(downloadBannerSummaryProvider);
    if (summary == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(activeDownloadsProvider.notifier);

    final cancelLabel = switch (summary.action) {
      DownloadBannerAction.cancelAll => l10n.cancelAllDownloads,
      DownloadBannerAction.cancelBatch ||
      DownloadBannerAction.cancelItem => l10n.cancelBatchDownload,
    };

    return DockProgressBanner(
      title: summary.title,
      subtitle: summary.subtitle,
      progress: summary.progress,
      actionLabel: cancelLabel,
      onAction: () {
        switch (summary.action) {
          case DownloadBannerAction.cancelItem:
            final id = summary.targetId;
            if (id != null) notifier.cancelDownload(id);
          case DownloadBannerAction.cancelBatch:
            final id = summary.targetId;
            if (id != null) notifier.cancelBatch(id);
          case DownloadBannerAction.cancelAll:
            notifier.cancelAll();
        }
      },
      onTap: () => context.go('/downloads'),
    );
  }
}
