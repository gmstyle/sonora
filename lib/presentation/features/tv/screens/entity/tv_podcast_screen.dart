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
import '../../../podcast/providers/podcast_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_actions_bar.dart';
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

class _TvPodcastBody extends ConsumerWidget {
  final PodcastFull podcast;

  const _TvPodcastBody({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offline = ref.watch(isOfflineProvider);
    final liked = ref
        .watch(likedPodcastProvider(podcast.browseId))
        .asData
        ?.value;
    final art = podcast.thumbnails.isNotEmpty
        ? podcast.thumbnails.last.url
        : null;
    final playable = podcast.episodes
        .where((e) => e.videoId.isNotEmpty)
        .toList();
    final headerH =
        MediaQuery.sizeOf(context).height * TvMetrics.entityHeaderFraction;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TvImmersiveEntityHeader(
              imageUrl: art,
              title: podcast.name,
              subtitle: podcast.author?.name,
              description: podcast.description,
              height: headerH,
              onBack: () => context.pop(),
              actions: TvEntityActionsBar(
                actions: [
                  TvEntityAction(
                    id: DetailActionId.play,
                    icon: LucideIcons.play,
                    label: l10n.playAll,
                    filled: true,
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
                  ),
                  TvEntityAction(
                    id: DetailActionId.shuffle,
                    icon: LucideIcons.shuffle,
                    label: l10n.shufflePlay,
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
                  ),
                  TvEntityAction(
                    id: DetailActionId.queue,
                    icon: LucideIcons.listMusic,
                    label: l10n.addToQueue,
                    onSelect: playable.isEmpty
                        ? null
                        : () => _addToQueue(context, ref),
                  ),
                  TvEntityAction(
                    id: DetailActionId.save,
                    icon: liked != null
                        ? LucideIcons.bookmarkCheck
                        : LucideIcons.bookmark,
                    label: liked != null ? l10n.subscribed : l10n.subscribe,
                    active: liked != null,
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
                  ),
                ],
                onOverflow: () => ContextMenuSheet.showForPodcast(
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
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.contentPadding,
              8,
              TvMetrics.contentPadding,
              48,
            ),
            sliver: SliverList.builder(
              itemCount: podcast.episodes.length,
              itemBuilder: (context, index) {
                final ep = podcast.episodes[index];
                return TvTrackRow(
                  index: index,
                  title: ep.name,
                  subtitle: ep.date,
                  enabled: ep.videoId.isNotEmpty,
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
                    onGoToPodcast: (id) => context.push('/podcast/$id'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToQueue(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final items = await ref
          .read(playPodcastUseCaseProvider)
          .execute(
            podcast.episodes,
            podcastBrowseId: podcast.browseId,
            podcastName: podcast.name,
            authorName: podcast.author?.name,
            authorId: podcast.author?.artistId,
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
