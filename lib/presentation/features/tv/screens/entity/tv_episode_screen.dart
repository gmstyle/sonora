import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/player_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/detail_actions_bar.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../podcast/providers/episode_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_actions_bar.dart';

class TvEpisodeScreen extends ConsumerWidget {
  final String videoId;

  const TvEpisodeScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(episodeProvider(videoId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: l10n.failedToLoadEpisode,
          onRetry: () => ref.invalidate(episodeProvider(videoId)),
        ),
      ),
      data: (episode) => _TvEpisodeBody(episode: episode),
    );
  }
}

class _TvEpisodeBody extends ConsumerWidget {
  final EpisodeFull episode;

  const _TvEpisodeBody({required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final liked = ref
        .watch(likedEpisodeProvider(episode.videoId))
        .asData
        ?.value;
    final art = episode.thumbnails.isNotEmpty
        ? episode.thumbnails.last.url
        : null;
    final headerH =
        MediaQuery.sizeOf(context).height * TvMetrics.entityHeaderFraction;

    return Scaffold(
      body: TvImmersiveEntityHeader(
        imageUrl: art,
        eyebrow: episode.podcastName,
        title: episode.name,
        description: episode.description,
        height: headerH.clamp(420.0, MediaQuery.sizeOf(context).height),
        onBack: () => context.pop(),
        actions: TvEntityActionsBar(
          actions: [
            TvEntityAction(
              id: DetailActionId.play,
              icon: LucideIcons.play,
              label: l10n.playNow,
              filled: true,
              autofocus: true,
              onSelect: () => ref
                  .read(playerStateProvider.notifier)
                  .playVideoId(episode.videoId),
            ),
            TvEntityAction(
              id: DetailActionId.queue,
              icon: LucideIcons.listMusic,
              label: l10n.addToQueue,
              onSelect: () {
                ref
                    .read(playerStateProvider.notifier)
                    .addToQueueVideoId(
                      episode.videoId,
                      title: episode.name,
                      artist: episode.podcastName ?? '',
                      thumbnailUrl: art,
                    );
                ref
                    .read(actionFeedbackProvider.notifier)
                    .report(l10n.addedToQueue(1));
              },
            ),
            TvEntityAction(
              id: DetailActionId.save,
              icon: liked != null
                  ? LucideIcons.bookmarkCheck
                  : LucideIcons.bookmark,
              label: l10n.like,
              active: liked != null,
              onSelect: () {
                ref
                    .read(libraryNotifierProvider.notifier)
                    .toggleLikedEpisode(
                      LikedEpisodeModel(
                        videoId: episode.videoId,
                        name: episode.name,
                        podcastName: episode.podcastName,
                        podcastBrowseId: episode.podcastId,
                        thumbnailUrl: art,
                        addedAt: DateTime.now(),
                      ),
                    );
              },
            ),
            if (episode.podcastId != null)
              TvEntityAction(
                id: 'podcast',
                icon: LucideIcons.podcast,
                label: l10n.podcasts,
                onSelect: () => context.push('/podcast/${episode.podcastId}'),
              ),
          ],
          onOverflow: () => ContextMenuSheet.showForEpisode(
            context,
            videoId: episode.videoId,
            name: episode.name,
            podcastName: episode.podcastName,
            podcastBrowseId: episode.podcastId,
            thumbnailUrl: art,
            onGoToPodcast: (id) => context.push('/podcast/$id'),
          ),
        ),
      ),
    );
  }
}
