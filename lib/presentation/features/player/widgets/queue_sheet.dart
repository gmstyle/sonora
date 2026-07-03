import 'package:audio_service/audio_service.dart';
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
      proxyDecorator:
          (child, index, animation) =>
              Material(color: Colors.transparent, child: child),
      onReorderItem: (oldIndex, newIndex) {
        notifier.moveQueueItem(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final item = queue[index];
        final queueId = item.extras?['queueId'] as String?;
        final key = ValueKey(
          queueId ??
              '${item.id}_${item.extras?['url'] ?? ''}_${item.duration?.inMilliseconds ?? 0}_$index',
        );
        return _QueueItem(
          key: key,
          item: item,
          index: index,
          currentIndex: currentIndex,
          pc: pc,
          onRemove: () => notifier.removeAt(index),
          onTap: () => notifier.skipToIndex(index),
        );
      },
    );
  }
}

class _QueueItem extends StatelessWidget {
  final MediaItem item;
  final int index;
  final int currentIndex;
  final PlayerColors pc;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _QueueItem({
    super.key,
    required this.item,
    required this.index,
    required this.currentIndex,
    required this.pc,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                          (_, _, _) =>
                              Icon(LucideIcons.music, color: pc.iconSecondary),
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
                  icon: Icon(LucideIcons.x, size: 18, color: pc.iconSecondary),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
        onTap: isCurrent ? null : onTap,
      ),
    );
  }
}
