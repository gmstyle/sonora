import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../podcast/providers/episode_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';

/// Scrollable episode show-notes panel for the full player.
class ShowNotesView extends ConsumerWidget {
  final String videoId;

  const ShowNotesView({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));
    final pc = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return episodeAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.all(16),
            child: ShimmerLoading(variant: ShimmerVariant.tile),
          ),
      error:
          (e, _) => ErrorRetryWidget(
            message: l10n.failedToLoadEpisode,
            onRetry: () => ref.invalidate(episodeProvider(videoId)),
          ),
      data: (episode) {
        final description = episode.description?.trim();
        if (description == null || description.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileText, size: 48, color: pc.labelMuted),
                const SizedBox(height: 16),
                Text(
                  l10n.noShowNotes,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: pc.subtitle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              l10n.showNotes,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: pc.titlePrimary,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: pc.subtitle,
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }
}
