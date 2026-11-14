import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/player_provider.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/thumbnail_widget.dart';
import '../../../podcast/providers/episode_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_focusable.dart';

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
    final theme = Theme.of(context);
    final liked = ref
        .watch(likedEpisodeProvider(episode.videoId))
        .asData
        ?.value;
    final art = episode.thumbnails.isNotEmpty
        ? episode.thumbnails.last.url
        : null;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(TvMetrics.contentPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TvFocusable(
                    onSelect: () => context.pop(),
                    child: const Icon(LucideIcons.arrowLeft, size: 28),
                  ),
                  const Spacer(),
                  ThumbnailWidget(
                    imageUrl: art,
                    size: 320,
                    shape: ThumbnailShape.rounded,
                    borderRadius: 24,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    episode.name,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (episode.podcastName != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      episode.podcastName!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (episode.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      episode.description!,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      TvFocusable(
                        autofocus: true,
                        onSelect: () => ref
                            .read(playerStateProvider.notifier)
                            .playVideoId(episode.videoId),
                        borderRadius: BorderRadius.circular(28),
                        child: FilledButton.icon(
                          onPressed: () => ref
                              .read(playerStateProvider.notifier)
                              .playVideoId(episode.videoId),
                          icon: const Icon(LucideIcons.play),
                          label: Text(l10n.playNow),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TvFocusable(
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
                        child: Icon(
                          liked != null
                              ? LucideIcons.bookmarkCheck
                              : LucideIcons.bookmark,
                          color: liked != null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                      ),
                      if (episode.podcastId != null) ...[
                        const SizedBox(width: 16),
                        TvFocusable(
                          onSelect: () =>
                              context.push('/podcast/${episode.podcastId}'),
                          borderRadius: BorderRadius.circular(28),
                          child: FilledButton.tonal(
                            onPressed: () =>
                                context.push('/podcast/${episode.podcastId}'),
                            child: Text(l10n.podcasts),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
