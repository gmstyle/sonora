import 'package:audio_service/audio_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/explicit_badge.dart';
import '../../../shared/widgets/shimmer_loading.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final pc = PlayerColors.of(context);
    final theme = Theme.of(context);

    final userQueue = playerState.userQueue;
    final upNextQueue = playerState.upNextQueue;
    final currentIndex = playerState.currentIndex;
    final autoplayEnabled = ref.watch(
      settingsProvider.select((s) => s.autoPlayUpNext),
    );

    if (playerState.isRestoring || !playerState.isQueueSynced) {
      return const ShimmerLoading(variant: ShimmerVariant.queue);
    }
    if (userQueue.isEmpty && upNextQueue.isEmpty) {
      return _EmptyState(pc: pc);
    }

    return CustomScrollView(
      slivers: [
        // ── Header "In coda" (user queue) ──────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(
            icon: LucideIcons.listMusic,
            title: AppLocalizations.of(context)!.playingNext,
            count: userQueue.length,
            pc: pc,
            theme: theme,
          ),
        ),
        if (userQueue.isNotEmpty)
          SliverReorderableList(
            itemCount: userQueue.length,
            proxyDecorator:
                (child, index, animation) =>
                    Material(color: Colors.transparent, child: child),
            onReorderItem: (oldIndex, newIndex) {
              // Items in userQueue live at the head of the global queue
              // (indices 0 .. upNextStartIndex-1, or the whole queue
              // when upnext is empty).
              final start =
                  playerState.upNextStartIndex ?? playerState.queue.length;
              if (oldIndex < 0 || oldIndex >= start) return;
              if (newIndex < 0 || newIndex > start) return;
              if (oldIndex == newIndex) return;
              notifier.moveQueueItem(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final item = userQueue[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(
                  'user_${item.extras?['queueId'] ?? item.id}_$index',
                ),
                index: index,
                child: _QueueItem(
                  item: item,
                  isCurrent: index == currentIndex,
                  pc: pc,
                  theme: theme,
                  showDragHandle: true,
                  onRemove: () => notifier.removeAt(index),
                  onTap: () => notifier.skipToIndex(index),
                ),
              );
            },
          )
        else
          SliverToBoxAdapter(
            child: _Hint(
              text: AppLocalizations.of(context)!.userQueueEmpty,
              pc: pc,
            ),
          ),

        // ── Header "Up Next" (autoplay) ────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(
            icon: LucideIcons.infinity,
            title: AppLocalizations.of(context)!.upNext,
            count: upNextQueue.length,
            pc: pc,
            theme: theme,
            autoplayEnabled: autoplayEnabled,
            onAutoplayToggle: () {
              ref
                  .read(settingsProvider.notifier)
                  .setAutoPlayUpNext(!autoplayEnabled);
            },
          ),
        ),
        if (upNextQueue.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = upNextQueue[index];
              final globalIndex = (playerState.upNextStartIndex ?? 0) + index;
              return _QueueItem(
                key: ValueKey(
                  'upnext_${item.extras?['queueId'] ?? item.id}_$index',
                ),
                item: item,
                isCurrent: globalIndex == currentIndex,
                pc: pc,
                theme: theme,
                // Upnext items are not individually removable; disable
                // autoplay to clear the section.
                onRemove: null,
                onTap: () => notifier.skipToIndex(globalIndex),
              );
            }, childCount: upNextQueue.length),
          )
        else
          SliverToBoxAdapter(
            child: _Hint(
              text:
                  autoplayEnabled
                      ? AppLocalizations.of(context)!.upNextWillPopulate
                      : AppLocalizations.of(context)!.autoplayDisabled,
              pc: pc,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final PlayerColors pc;
  final ThemeData theme;
  final bool? autoplayEnabled;
  final VoidCallback? onAutoplayToggle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.pc,
    required this.theme,
    this.autoplayEnabled,
    this.onAutoplayToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: pc.labelMuted),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: pc.labelMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pc.labelMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pc.labelMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (autoplayEnabled != null && onAutoplayToggle != null)
            IconButton(
              tooltip:
                  autoplayEnabled!
                      ? AppLocalizations.of(context)!.autoplayDisable
                      : AppLocalizations.of(context)!.autoplayEnable,
              icon: Icon(
                autoplayEnabled!
                    ? LucideIcons.toggleRight
                    : LucideIcons.toggleLeft,
                size: 22,
                color: autoplayEnabled! ? pc.iconPrimary : pc.iconSecondary,
              ),
              onPressed: onAutoplayToggle,
            ),
        ],
      ),
    );
  }
}

// ── Queue item ─────────────────────────────────────────────────────────────

class _QueueItem extends StatelessWidget {
  final MediaItem item;
  final bool isCurrent;
  final PlayerColors pc;
  final ThemeData theme;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool showDragHandle;

  const _QueueItem({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.pc,
    required this.theme,
    this.onRemove,
    this.onTap,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUpNext = item.extras?['section'] == 'upnext';
    final opacity =
        isCurrent
            ? 1.0
            : isUpNext
            ? 0.7
            : 0.9;

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
                if (QueueTrack.fromMediaItem(item).isExplicit)
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 4),
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
                : onRemove == null
                ? Icon(
                  LucideIcons.infinity,
                  size: 16,
                  color: pc.iconSecondary.withValues(alpha: 0.6),
                )
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

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final PlayerColors pc;
  const _EmptyState({required this.pc});

  @override
  Widget build(BuildContext context) {
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
}

// ── Hint text under an empty section ───────────────────────────────────────

class _Hint extends StatelessWidget {
  final String text;
  final PlayerColors pc;
  const _Hint({required this.text, required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Text(text, style: TextStyle(color: pc.subtitle, fontSize: 13)),
    );
  }
}
