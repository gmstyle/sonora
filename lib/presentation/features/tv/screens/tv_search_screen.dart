import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../search/providers/search_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

/// TV search: system IME field + poster grid results.
class TvSearchScreen extends ConsumerStatefulWidget {
  const TvSearchScreen({super.key});

  @override
  ConsumerState<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends ConsumerState<TvSearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'tvSearchField');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    final offline = ref.read(isOfflineProvider);
    if (offline) return;
    ref.read(searchQueryProvider.notifier).update(query);
    ref.read(activeSearchQueryProvider.notifier).submit(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final offline = ref.watch(isOfflineProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final activeQuery = ref.watch(activeSearchQueryProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.contentPadding,
            32,
            TvMetrics.contentPadding,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TvFocusable(
                  autofocus: true,
                  onSelect: () => _fieldFocus.requestFocus(),
                  onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _controller,
                    focusNode: _fieldFocus,
                    enabled: !offline,
                    style: theme.textTheme.headlineSmall,
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const Icon(LucideIcons.search, size: 28),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (v) =>
                        ref.read(searchQueryProvider.notifier).update(v),
                    onSubmitted: _submit,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              TvFocusable(
                onSelect: offline ? null : () => _submit(_controller.text),
                borderRadius: BorderRadius.circular(28),
                child: FilledButton(
                  onPressed: offline ? null : () => _submit(_controller.text),
                  child: Text(l10n.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: activeQuery.isEmpty
              ? EmptyStateWidget(
                  icon: LucideIcons.search,
                  title: l10n.search,
                  body: l10n.noResults,
                )
              : resultsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(TvMetrics.contentPadding),
                    child: ShimmerLoading(
                      variant: ShimmerVariant.mediaGrid,
                      gridColumns: 5,
                    ),
                  ),
                  error: (e, _) => ErrorRetryWidget(
                    message: l10n.noResults,
                    onRetry: () => ref.invalidate(searchResultsProvider),
                  ),
                  data: (results) {
                    if (results.isEmpty) {
                      return EmptyStateWidget(
                        icon: LucideIcons.searchX,
                        title: l10n.noResults,
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(TvMetrics.contentPadding),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: TvMetrics.shelfCardWidth + 24,
                            mainAxisExtent: TvMetrics.shelfRowHeight,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        return _TvSearchResultCard(
                          result: results[index],
                          isLeading: index == 0,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TvSearchResultCard extends ConsumerWidget {
  final SearchResult result;
  final bool isLeading;

  const _TvSearchResultCard({required this.result, required this.isLeading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onLeft = isLeading
        ? () => TvShellFocus.requestSidebar(context)
        : null;

    if (result is SongDetailed) {
      final song = result as SongDetailed;
      return TvPosterCard(
        title: song.name,
        subtitle: displayArtists(song.artists),
        imageUrl: song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => ref
            .read(playerStateProvider.notifier)
            .playVideoId(
              song.videoId,
              isVideo: song.type == 'VIDEO',
              isExplicit: song.isExplicit,
            ),
      );
    }
    if (result is VideoDetailed) {
      final video = result as VideoDetailed;
      return TvPosterCard(
        title: video.name,
        subtitle: displayArtists(video.artists),
        imageUrl: video.thumbnails.isNotEmpty
            ? video.thumbnails.last.url
            : null,
        onLeftAtEdge: onLeft,
        onSelect: () => ref
            .read(playerStateProvider.notifier)
            .playVideoId(
              video.videoId,
              isVideo: true,
              isExplicit: video.isExplicit,
            ),
      );
    }
    if (result is AlbumDetailed) {
      final album = result as AlbumDetailed;
      return TvPosterCard(
        title: album.name,
        subtitle: displayArtists(album.artists),
        imageUrl: album.thumbnails.isNotEmpty
            ? album.thumbnails.last.url
            : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/album/${album.albumId}'),
      );
    }
    if (result is ArtistDetailed) {
      final artist = result as ArtistDetailed;
      return TvPosterCard(
        title: artist.name,
        imageUrl: artist.thumbnails.isNotEmpty
            ? artist.thumbnails.last.url
            : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/artist/${artist.artistId}'),
      );
    }
    if (result is PlaylistDetailed) {
      final playlist = result as PlaylistDetailed;
      return TvPosterCard(
        title: playlist.name,
        subtitle: displayArtists(playlist.artists),
        imageUrl: playlist.thumbnails.isNotEmpty
            ? playlist.thumbnails.last.url
            : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/playlist/${playlist.playlistId}'),
      );
    }
    if (result is PodcastDetailed) {
      final podcast = result as PodcastDetailed;
      return TvPosterCard(
        title: podcast.name,
        subtitle: podcast.author,
        imageUrl: podcast.thumbnails.isNotEmpty
            ? podcast.thumbnails.last.url
            : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/podcast/${podcast.browseId}'),
      );
    }
    if (result is EpisodeDetailed) {
      final episode = result as EpisodeDetailed;
      return TvPosterCard(
        title: episode.name,
        subtitle: episode.podcastName,
        imageUrl: episode.thumbnails.isNotEmpty
            ? episode.thumbnails.last.url
            : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/episode/${episode.videoId}'),
      );
    }
    return const SizedBox.shrink();
  }
}
