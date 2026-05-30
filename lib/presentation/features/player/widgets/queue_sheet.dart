import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/player_provider.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final notifier = ref.read(playerStateProvider.notifier);

    if (queue.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.queueIsEmpty,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: queue.length,
      onReorderItem: (oldIndex, newIndex) {
        notifier.moveQueueItem(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = queue[index];
        final isCurrent = index == currentIndex;

        double opacity;
        if (isCurrent) {
          opacity = 1.0;
        } else if (index == currentIndex + 1) {
          opacity = 0.87;
        } else {
          opacity = 0.6;
        }

        return Opacity(
          key: ValueKey('${item.id}_$index'),
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
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                        )
                        : Icon(
                          LucideIcons.music,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            subtitle: Text(
              item.artist ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing:
                isCurrent
                    ? Icon(
                      LucideIcons.play,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    )
                    : IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
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
