import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import 'player_bouncing_widget.dart';
import 'player_shared_widgets.dart';

/// One row in the full-player up-next companion.
class UpcomingTrack {
  const UpcomingTrack({required this.item, required this.queueIndex});

  final MediaItem item;

  /// Index in [PlayerState.queue], when the row came from that list.
  final int? queueIndex;
}

/// Tracks after the current one, in play order, capped at [limit].
///
/// The live queue wins. [PlayerState.upNextQueue] fills the list only when
/// nothing follows [PlayerState.currentIndex].
List<UpcomingTrack> upcomingTracks(PlayerState state, {int limit = 6}) {
  if (limit <= 0) return const [];
  final queue = state.queue;
  final start = state.currentIndex + 1;
  if (start >= 0 && start < queue.length) {
    final count = queue.length - start;
    final take = count < limit ? count : limit;
    return [
      for (var i = 0; i < take; i++)
        UpcomingTrack(item: queue[start + i], queueIndex: start + i),
    ];
  }
  final extra = state.upNextQueue;
  final take = extra.length < limit ? extra.length : limit;
  return [
    for (var i = 0; i < take; i++)
      UpcomingTrack(item: extra[i], queueIndex: null),
  ];
}

/// Up-next list that sits beside the artwork instead of replacing it.
class UpNextCompanion extends ConsumerWidget {
  const UpNextCompanion({
    super.key,
    required this.maxItems,
    this.showSleepBadge = false,
    this.shrinkWrap = false,
  });

  final int maxItems;
  final bool showSleepBadge;

  /// Sizes to the rows. Mobile puts this under the disc in the center slot.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final current = state.currentSong;
    if (current == null) return const SizedBox.shrink();

    final upcoming = upcomingTracks(state, limit: maxItems);
    final currentIsEpisode = QueueTrack.fromMediaItem(current).isEpisode;

    final list = upcoming.isEmpty
        ? _EmptyUpNext(episodeShaped: currentIsEpisode)
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: upcoming.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = upcoming[index];
              final nextIsEpisode = QueueTrack.fromMediaItem(row.item)
                  .isEpisode;
              return _UpNextRow(
                item: row.item,
                isFirst: index == 0,
                nextIsEpisode: nextIsEpisode,
                onTap: state.isBlocked
                    ? null
                    : () {
                        final notifier = ref.read(playerStateProvider.notifier);
                        final queueIndex = row.queueIndex;
                        if (index == 0 || queueIndex == null) {
                          notifier.skipToNext();
                        } else {
                          notifier.skipToIndex(queueIndex);
                        }
                      },
              );
            },
          );

    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSleepBadge) const PlayerSleepBadge(),
        if (shrinkWrap) list else Expanded(child: list),
      ],
    );
  }
}

/// Countdown chip. Hidden when no sleep timer is armed.
class PlayerSleepBadge extends ConsumerWidget {
  const PlayerSleepBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final remaining = state.sleepTimerRemaining;
    final untilEnd = state.sleepUntilEndOfTrack;
    if (remaining == null && !untilEnd) return const SizedBox.shrink();

    final pc = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = untilEnd
        ? l10n.sleepEndOfEpisode
        : _clock(remaining ?? Duration.zero);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: BouncingWidget(
          onTap: () => showPlayerTimerDialog(
            context,
            ref.read(playerStateProvider.notifier),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pc.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pc.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.timer, size: 16, color: pc.accent),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: pc.titlePrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _clock(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.item,
    required this.isFirst,
    required this.nextIsEpisode,
    required this.onTap,
  });

  final MediaItem item;
  final bool isFirst;
  final bool nextIsEpisode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final label = nextIsEpisode ? l10n.nextEpisode : l10n.upNext;

    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: item.artUri != null
                      ? CachedNetworkImage(
                          imageUrl: item.artUri!.toString(),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Icon(
                            LucideIcons.music,
                            color: pc.iconSecondary,
                            size: 22,
                          ),
                        )
                      : Icon(
                          LucideIcons.music,
                          color: pc.iconSecondary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: pc.labelMuted,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (isFirst) ...[
                          const SizedBox(width: 6),
                          const PulsingDot(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: pc.titlePrimary,
                      ),
                    ),
                    Text(
                      item.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: pc.subtitle),
                    ),
                  ],
                ),
              ),
              if (isFirst)
                Icon(
                  LucideIcons.skipForward,
                  color: pc.iconSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyUpNext extends ConsumerWidget {
  const _EmptyUpNext({required this.episodeShaped});

  final bool episodeShaped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pc = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isAutoplay = ref.watch(
      settingsProvider.select((s) => s.autoPlayUpNext),
    );
    final isOffline = ref.watch(isOfflineProvider);
    final title = episodeShaped
        ? l10n.nextEpisode
        : (isAutoplay ? l10n.autoplayLabel : l10n.queueEndLabel);
    final body = episodeShaped
        ? l10n.noUpcomingEpisodes
        : (isAutoplay ? l10n.autoplayActive : l10n.noUpcomingSongs);

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                episodeShaped
                    ? LucideIcons.podcast
                    : (isAutoplay ? LucideIcons.infinity : LucideIcons.music),
                color: pc.iconSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pc.labelMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: pc.titleSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAutoplay && !episodeShaped)
                TextButton(
                  onPressed: isOffline
                      ? null
                      : () {
                          ref
                              .read(settingsProvider.notifier)
                              .setAutoPlayUpNext(true);
                        },
                  child: Text(l10n.autoplayEnable),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
