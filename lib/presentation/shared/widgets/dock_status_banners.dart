import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/download_provider.dart';
import '../../providers/playlist_import_job_provider.dart';
import 'download_progress_banner.dart';
import 'import_progress_banner.dart';

/// Stacks dock progress chips (import + downloads) above the mini-player.
class DockStatusBanners extends ConsumerWidget {
  const DockStatusBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showImport = ref.watch(playlistImportJobProvider).showInDockBanner;
    final showDownloads = ref.watch(downloadBannerSummaryProvider) != null;
    if (!showImport && !showDownloads) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showImport) const ImportProgressBanner(),
        if (showDownloads) const DownloadProgressBanner(),
      ],
    );
  }
}
