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
import '../../../podcast/podcast_screen.dart';
import '../../../podcast/providers/podcast_provider.dart';
import '../../tv_metrics.dart';
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

class _TvPodcastBody extends ConsumerWidget {
  final PodcastFull podcast;

  const _TvPodcastBody({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 420,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const reserved = 240.0;
                final artSize = (constraints.maxHeight - reserved)
                    .clamp(120.0, 280.0)
                    .clamp(
                      120.0,
                      constraints.maxWidth - TvMetrics.contentPadding * 2,
                    )
                    .toDouble();
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(TvMetrics.contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TvFocusable(
                        onSelect: () => context.pop(),
                        child: const Icon(LucideIcons.arrowLeft, size: 28),
                      ),
                      const SizedBox(height: 24),
                      ThumbnailWidget(
                        imageUrl: art,
                        size: artSize,
                        shape: ThumbnailShape.rounded,
                        borderRadius: 20,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        podcast.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (podcast.author != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          podcast.author!.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          TvFocusable(
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
                            borderRadius: BorderRadius.circular(28),
                            child: FilledButton.icon(
                              onPressed: playable.isEmpty
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
                              icon: const Icon(LucideIcons.play),
                              label: Text(l10n.playAll),
                            ),
                          ),
                          TvFocusable(
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
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 48, 48, 48),
              itemCount: podcast.episodes.length,
              itemBuilder: (context, index) {
                final ep = podcast.episodes[index];
                final enabled = ep.videoId.isNotEmpty;
                return TvTrackRow(
                  index: index,
                  title: ep.name,
                  subtitle: ep.date,
                  enabled: enabled,
                  onSelect: () {
                    final start = playableIndexForEpisode(podcast, index);
                    if (start < 0) return;
                    ref
                        .read(playerStateProvider.notifier)
                        .playPodcast(
                          podcast.episodes,
                          podcastBrowseId: podcast.browseId,
                          podcastName: podcast.name,
                          authorName: podcast.author?.name,
                          authorId: podcast.author?.artistId,
                          startIndex: start,
                        );
                  },
                  onLongSelect: enabled
                      ? () => context.push('/episode/${ep.videoId}')
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
