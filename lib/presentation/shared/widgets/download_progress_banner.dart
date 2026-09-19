import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';

/// Persistent chip above the mini-player while downloads are active.
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

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(activeDownloadsProvider.notifier);

    final cancelLabel = switch (summary.action) {
      DownloadBannerAction.cancelAll => l10n.cancelAllDownloads,
      DownloadBannerAction.cancelBatch ||
      DownloadBannerAction.cancelItem => l10n.cancelBatchDownload,
    };

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: () => context.go('/downloads'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                LucideIcons.download,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    if (summary.subtitle != null)
                      Text(
                        summary.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    if (summary.progress != null) ...[
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: summary.progress,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
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
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
