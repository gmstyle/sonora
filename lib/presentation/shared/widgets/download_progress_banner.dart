import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';

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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(activeDownloadsProvider.notifier);

    final cancelLabel = switch (summary.action) {
      DownloadBannerAction.cancelAll => l10n.cancelAllDownloads,
      DownloadBannerAction.cancelBatch ||
      DownloadBannerAction.cancelItem => l10n.cancelBatchDownload,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/downloads'),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
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
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (summary.subtitle != null)
                          Text(
                            summary.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (summary.progress != null) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: summary.progress,
                              minHeight: 3,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              color: colorScheme.primary,
                            ),
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
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(cancelLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
