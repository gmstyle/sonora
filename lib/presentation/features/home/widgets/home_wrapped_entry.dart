import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../library/widgets/open_wrapped.dart';
import '../../library/widgets/sonora_wrapped_banner.dart';
import '../layouts/home_layout_metrics.dart';

/// Wrapped entry in the Home resume zone.
///
/// On mobile it sits above the resume row, full width. On tablet and wide,
/// [embedded] places it in the mixes column so it keeps a card width instead
/// of stretching across the feed.
class HomeWrappedEntry extends ConsumerWidget {
  final HomeLayoutMetrics metrics;

  /// Pads like the mix tiles inside the side-by-side resume row.
  final bool embedded;

  const HomeWrappedEntry({
    super.key,
    required this.metrics,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final seen = ref.watch(settingsProvider.select((s) => s.wrappedSeen));
    if (stats.isLoading || !stats.isWrappedAvailable) {
      return const SizedBox.shrink();
    }

    final child =
        seen
            ? _ReplayRow(onTap: () => openSonoraWrapped(context, ref))
            : SonoraWrappedBanner(
              onOpen: () => openSonoraWrapped(context, ref),
            );

    final padding =
        embedded
            ? EdgeInsets.fromLTRB(
              metrics.quickRowPadding,
              0,
              metrics.quickRowPadding,
              metrics.zoneGap,
            )
            : EdgeInsets.fromLTRB(
              metrics.horizontalPadding,
              4,
              metrics.horizontalPadding,
              8,
            );

    return Padding(padding: padding, child: child);
  }
}

class _ReplayRow extends StatelessWidget {
  final VoidCallback onTap;

  const _ReplayRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(LucideIcons.partyPopper, color: scheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.wrappedReplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
