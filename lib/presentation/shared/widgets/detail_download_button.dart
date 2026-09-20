import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Download control with progress / complete states for detail headers.
class DetailDownloadButton extends StatelessWidget {
  final bool iconOnly;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool emphasize;

  const DetailDownloadButton({
    super.key,
    required this.iconOnly,
    required this.icon,
    required this.label,
    this.onPressed,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    if (iconOnly) {
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: emphasize ? primary : null,
        tooltip: label,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style:
          emphasize ? FilledButton.styleFrom(foregroundColor: primary) : null,
    );
  }

  /// Resolve icon/label for a batch download progress snapshot.
  static ({IconData icon, String label, bool emphasize, bool busy})
  resolveState({
    required bool batchActive,
    required bool allDownloaded,
    required int downloadedCount,
    required int totalCount,
    required int? batchCompleted,
    required int? batchTotal,
    required String idleLabel,
    required String Function(int done, int total) countLabel,
  }) {
    if (batchActive) {
      final done = batchCompleted ?? downloadedCount;
      return (
        icon: LucideIcons.loader,
        label: countLabel(done, batchTotal ?? totalCount),
        emphasize: true,
        busy: true,
      );
    }
    if (allDownloaded) {
      return (
        icon: LucideIcons.checkCircle,
        label: countLabel(downloadedCount, totalCount),
        emphasize: true,
        busy: false,
      );
    }
    if (downloadedCount > 0) {
      return (
        icon: LucideIcons.download,
        label: countLabel(downloadedCount, totalCount),
        emphasize: true,
        busy: false,
      );
    }
    return (
      icon: LucideIcons.download,
      label: idleLabel,
      emphasize: false,
      busy: false,
    );
  }
}
