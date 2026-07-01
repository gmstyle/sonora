import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/explicit_badge.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final notifier = ref.read(playerStateProvider.notifier);

    // All colours from PlayerColors — single source of truth for the
    // player overlay surface.
    final pc = PlayerColors.of(context);

    if (queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.listMusic, size: 40, color: pc.labelMuted),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.queueIsEmpty,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: pc.subtitle),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: queue.length,
      // Make the drag handle icon white so it's visible on the dark bg.
      proxyDecorator:
          (child, index, animation) =>
              Material(color: Colors.transparent, child: child),
      onReorderItem: (oldIndex, newIndex) {
        notifier.moveQueueItem(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = queue[index];
        final isCurrent = index == currentIndex;

        // Opacity steps give hierarchy without relying on colour changes alone.
        final double opacity;
        if (isCurrent) {
          opacity = 1.0;
        } else if (index == currentIndex + 1) {
          opacity = 0.85;
        } else {
          opacity = 0.55;
        }

        return Opacity(
          key: ValueKey(item.extras?['queueId'] ?? item.id),
          opacity: opacity,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 48,
                height: 48,
                child:
                    item.artUri != null
                        ? CachedNetworkImage(
                          imageUrl: item.artUri!.toString(),
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, _, _) => Icon(
                                LucideIcons.music,
                                color: pc.iconSecondary,
                              ),
                        )
                        : Icon(LucideIcons.music, color: pc.iconSecondary),
              ),
            ),
            title: DefaultTextStyle(
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent ? pc.titlePrimary : pc.titleSecondary,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    if (item.extras?['isExplicit'] == true)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ExplicitBadge(),
                        ),
                      ),
                    TextSpan(text: item.title),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            subtitle: Text(
              item.artist ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: pc.subtitle),
            ),
            trailing:
                isCurrent
                    ? Icon(LucideIcons.play, size: 20, color: pc.iconPrimary)
                    : IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: pc.iconSecondary,
                      ),
                      onPressed: () => notifier.removeAt(index),
                      visualDensity: VisualDensity.compact,
                    ),
            onTap: isCurrent ? null : () => notifier.skipToIndex(index),
          ),
        );
      },
    );
  }
}
