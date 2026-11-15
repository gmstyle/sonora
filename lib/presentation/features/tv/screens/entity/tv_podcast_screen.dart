import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/play_podcast_use_case_provider.dart';
import '../../../../providers/player_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/detail_actions_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/thumbnail_widget.dart';
import '../../../podcast/providers/podcast_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_side_column.dart';
import '../../widgets/tv_focusable.dart';
import '../../widgets/tv_track_row.dart';

class TvPodcastScreen extends ConsumerWidget {
  final String browseId;

  const TvPodcastScreen({super.key, required this.browseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(podcastProvider(browseId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: l10n.failedToLoadPodcast,
          onRetry: () => ref.invalidate(podcastProvider(browseId)),
        ),
      ),
      data: (podcast) => _TvPodcastBody(podcast: podcast),
    );
  }
}

class _TvPodcastBody extends ConsumerStatefulWidget {
  final PodcastFull podcast;

  const _TvPodcastBody({required this.podcast});

  @override
  ConsumerState<_TvPodcastBody> createState() => _TvPodcastBodyState();
}

class _TvPodcastBodyState extends ConsumerState<_TvPodcastBody> {
  final FocusNode _playAllFocus = FocusNode(debugLabel: 'tvPodcastPlayAll');

  @override
  void dispose() {
    _playAllFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final podcast = widget.podcast;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final offline = ref.watch(isOfflineProvider);
    final liked = ref
        .watch(likedPodcastProvider(podcast.browseId))
        .asData
        ?.value;
    final playingVideoId = ref.watch(
      playerStateProvider.select((s) => s.currentSong?.id),
    );
    final art = podcast.thumbnails.isNotEmpty
        ? podcast.thumbnails.last.url
        : null;
    final playable = podcast.episodes
        .where((e) => e.videoId.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: TvColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.overscanHorizontal,
            TvMetrics.overscanVertical,
            TvMetrics.overscanHorizontal,
            TvMetrics.overscanVertical,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TvEntitySideColumn(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvFocusable(
                      onSelect: () => context.pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TvColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.chevronLeft,
                              size: 16,
                              color: TvColors.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.askIntroBack,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: TvColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ThumbnailWidget(
                      imageUrl: art,
                      size: 164,
                      shape: ThumbnailShape.rounded,
                      borderRadius: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    podcast.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: TvColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (podcast.author?.name != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      podcast.author!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    '${podcast.episodes.length} ${l10n.episodes}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: TvColors.textSecondary,
                    ),
                  ),
                  if (podcast.description != null &&
                      podcast.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      podcast.description!.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: TvColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 224,
                    child: Column(
                      children: [
                        TvFocusable(
                          focusNode: _playAllFocus,
                          autofocus: true,
                          onSelect: playable.isEmpty
                              ? null
                              : () => ref
                                    .read(playerStateProvider.notifier)
                                    .playPodcast(
                                      podcast.episodes,
                                      podcastBrowseId: podcast.browseId,
                                      podcastName: podcast.name,
                                      authorName: podcast.author?.name,
                                      authorId: podcast.author?.artistId,
                                      startIndex: 0,
                                    ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.play,
                                  size: 16,
                                  color: colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.playAll,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TvFocusable(
                          onSelect: playable.isEmpty
                              ? null
                              : () {
                                  final shuffled = List<PodcastEpisode>.from(
                                    podcast.episodes,
                                  )..shuffle();
                                  ref
                                      .read(playerStateProvider.notifier)
                                      .playPodcast(
                                        shuffled,
                                        podcastBrowseId: podcast.browseId,
                                        podcastName: podcast.name,
                                        authorName: podcast.author?.name,
                                        authorId: podcast.author?.artistId,
                                        startIndex: 0,
                                      );
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TvColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.shuffle,
                                  size: 15,
                                  color: TvColors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.shufflePlay,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: TvColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TvFocusable(
                                onSelect: () {
                                  ref
                                      .read(libraryNotifierProvider.notifier)
                                      .toggleLikedPodcast(
                                        LikedPodcastModel(
                                          browseId: podcast.browseId,
                                          name: podcast.name,
                                          authorName: podcast.author?.name,
                                          authorId: podcast.author?.artistId,
                                          thumbnailUrl: art,
                                          episodeCount: podcast.episodes.length,
                                          addedAt: DateTime.now(),
                                        ),
                                      );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: liked != null
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.16,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: liked != null
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.4,
                                            )
                                          : TvColors.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        liked != null
                                            ? LucideIcons.bookmarkCheck
                                            : LucideIcons.bookmark,
                                        size: 15,
                                        color: liked != null
                                            ? colorScheme.primary
                                            : TvColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        liked != null
                                            ? l10n.subscribed
                                            : l10n.subscribe,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: liked != null
                                                  ? colorScheme.primary
                                                  : TvColors.textPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TvFocusable(
                              onSelect: playable.isEmpty
                                  ? null
                                  : () => _addToQueue(context, ref),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: TvColors.borderSubtle,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.listMusic,
                                  size: 17,
                                  color: TvColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TvFocusable(
                              onSelect: () => ContextMenuSheet.showForPodcast(
                                context,
                                browseId: podcast.browseId,
                                name: podcast.name,
                                author: podcast.author?.name,
                                thumbnailUrl: art,
                                omitActionIds: {
                                  DetailActionId.play,
                                  DetailActionId.shuffle,
                                  DetailActionId.queue,
                                  DetailActionId.save,
                                  DetailActionId.share,
                                  if (offline) DetailActionId.download,
                                },
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: TvColors.borderSubtle,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.ellipsisVertical,
                                  size: 17,
                                  color: TvColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.episodes.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: TvColors.textSecondary,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: TvColors.border),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: podcast.episodes.length,
                        itemBuilder: (context, index) {
                          final ep = podcast.episodes[index];
                          return TvTrackRow(
                            index: index,
                            title: ep.name,
                            subtitle: ep.date,
                            duration: ep.duration,
                            isPlaying: playingVideoId == ep.videoId,
                            enabled: ep.videoId.isNotEmpty,
                            onLeftAtEdge: () => _playAllFocus.requestFocus(),
                            onSelect: () {
                              if (ep.videoId.isEmpty) return;
                              ref
                                  .read(playerStateProvider.notifier)
                                  .playPodcast(
                                    podcast.episodes,
                                    podcastBrowseId: podcast.browseId,
                                    podcastName: podcast.name,
                                    authorName: podcast.author?.name,
                                    authorId: podcast.author?.artistId,
                                    startIndex: index,
                                  );
                            },
                            onLongSelect: () => ContextMenuSheet.showForEpisode(
                              context,
                              videoId: ep.videoId,
                              name: ep.name,
                              podcastName: podcast.name,
                              podcastBrowseId: podcast.browseId,
                              thumbnailUrl: ep.thumbnails.isNotEmpty
                                  ? ep.thumbnails.last.url
                                  : art,
                              date: ep.date,
                              onGoToPodcast: (id) =>
                                  context.push('/podcast/$id'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToQueue(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final items = await ref
          .read(playPodcastUseCaseProvider)
          .execute(
            widget.podcast.episodes,
            podcastBrowseId: widget.podcast.browseId,
            podcastName: widget.podcast.name,
            authorName: widget.podcast.author?.name,
            authorId: widget.podcast.author?.artistId,
            playIndex: -1,
          );
      if (items.isNotEmpty) {
        await ref.read(playerStateProvider.notifier).addAllToQueue(items);
      }
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add podcast to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
      }
    }
  }
}
