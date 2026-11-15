import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../search/providers/search_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

const _kTvQuickGenres = [
  ('Pop', 'Pop', Color(0xFFE11D48), Color(0xFFBE123C)),
  ('Hip Hop', 'Hip Hop', Color(0xFF7E22CE), Color(0xFF581C87)),
  ('Electronic', 'Electronic', Color(0xFF2563EB), Color(0xFF0284C7)),
  ('Rock', 'Rock', Color(0xFFD97706), Color(0xFFB45309)),
  ('Chill', 'Relax & Chill', Color(0xFF059669), Color(0xFF047857)),
  ('R&B', 'R&B', Color(0xFFDC2626), Color(0xFF991B1B)),
  ('Jazz & Blues', 'Jazz & Blues', Color(0xFF7C3AED), Color(0xFFC026D3)),
  ('Workout', 'Workout & Focus', Color(0xFF0D9488), Color(0xFF0F766E)),
];

/// TV search: system IME field + instant genre discovery + poster grid results.
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
    _controller.text = query;
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
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Search Input Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.contentPadding,
            TvMetrics.browseTopPadding,
            TvMetrics.contentPadding,
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _fieldFocus,
                  builder: (context, child) {
                    final focused = _fieldFocus.hasFocus;
                    return AnimatedContainer(
                      duration: TvMetrics.drawerAnimDuration,
                      decoration: BoxDecoration(
                        color: TvColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: focused
                              ? colorScheme.primary
                              : TvColors.border,
                          width: focused ? 2.5 : 1,
                        ),
                        boxShadow: focused
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                      child: child,
                    );
                  },
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        FocusScope.of(context)
                            .focusInDirection(TraversalDirection.down);
                        return KeyEventResult.handled;
                      }
                      final sel = _controller.selection;
                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                          (_controller.text.isEmpty ||
                              (sel.isCollapsed && sel.baseOffset <= 0))) {
                        TvShellFocus.requestSidebar(context);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                          (_controller.text.isEmpty ||
                              (sel.isCollapsed &&
                                  sel.baseOffset >= _controller.text.length))) {
                        FocusScope.of(context)
                            .focusInDirection(TraversalDirection.right);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _fieldFocus,
                      autofocus: activeQuery.isEmpty,
                      enabled: !offline,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: TvColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        hintStyle: theme.textTheme.titleSmall?.copyWith(
                          color: TvColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 20,
                          color: TvColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (v) =>
                          ref.read(searchQueryProvider.notifier).update(v),
                      onSubmitted: _submit,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search Submit Pill Button (single FocusNode via TvFocusable)
              TvFocusable(
                onSelect: offline ? null : () => _submit(_controller.text),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: offline
                        ? TvColors.surfaceButton
                        : colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: offline
                        ? null
                        : [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 16,
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.search,
                        size: 17,
                        color: offline
                            ? TvColors.textSecondary
                            : colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.search,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: offline
                              ? TvColors.textSecondary
                              : colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body Content
        Expanded(
          child: activeQuery.isEmpty
              ? _TvSearchGenreDiscovery(onSelectGenre: _submit)
              : resultsAsync.when(
                  loading: () => const SingleChildScrollView(
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.all(TvMetrics.contentPadding),
                    child: ShimmerLoading(
                      variant: ShimmerVariant.mediaGrid,
                      gridColumns: 4,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: TvMetrics.contentPadding,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        return _TvSearchResultCard(result: results[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TvSearchGenreDiscovery extends StatelessWidget {
  final ValueChanged<String> onSelectGenre;

  const _TvSearchGenreDiscovery({required this.onSelectGenre});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TvMetrics.contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.moodsAndGenres.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 76,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _kTvQuickGenres.length,
              itemBuilder: (context, index) {
                final genre = _kTvQuickGenres[index];
                final label = switch (index) {
                  4 => l10n.mixMoodChill,
                  7 => l10n.mixMoodWorkout,
                  _ => genre.$1,
                };
                return TvFocusable(
                  onSelect: () => onSelectGenre(genre.$2),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [genre.$3, genre.$4],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvSearchResultCard extends ConsumerWidget {
  final SearchResult result;

  const _TvSearchResultCard({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result is SongDetailed) {
      final song = result as SongDetailed;
      final art = song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null;
      return TvPosterCard(
        title: song.name,
        subtitle: displayArtists(song.artists),
        imageUrl: art,
        onSelect: () => ref
            .read(playerStateProvider.notifier)
            .playVideoId(
              song.videoId,
              isVideo: song.type == 'VIDEO',
              isExplicit: song.isExplicit,
            ),
        onLongSelect: () => ContextMenuSheet.showForSong(
          context,
          videoId: song.videoId,
          title: song.name,
          artist: displayArtists(song.artists),
          artists: song.artists,
          thumbnailUrl: art,
          duration: song.duration,
          isVideo: song.type == 'VIDEO',
          isExplicit: song.isExplicit,
          isPlayable: song.isPlayable,
        ),
      );
    }
    if (result is VideoDetailed) {
      final video = result as VideoDetailed;
      final art = video.thumbnails.isNotEmpty
          ? video.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: video.name,
        subtitle: displayArtists(video.artists),
        imageUrl: art,
        onSelect: () => ref
            .read(playerStateProvider.notifier)
            .playVideoId(
              video.videoId,
              isVideo: true,
              isExplicit: video.isExplicit,
            ),
        onLongSelect: () => ContextMenuSheet.showForSong(
          context,
          videoId: video.videoId,
          title: video.name,
          artist: displayArtists(video.artists),
          artists: video.artists,
          thumbnailUrl: art,
          duration: video.duration,
          isVideo: true,
          isExplicit: video.isExplicit,
          isPlayable: video.isPlayable,
        ),
      );
    }
    if (result is AlbumDetailed) {
      final album = result as AlbumDetailed;
      final art = album.thumbnails.isNotEmpty
          ? album.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: album.name,
        subtitle: displayArtists(album.artists),
        imageUrl: art,
        onSelect: () => context.push('/album/${album.albumId}'),
        onLongSelect: () => ContextMenuSheet.showForAlbum(
          context,
          albumId: album.albumId,
          name: album.name,
          artist: displayArtists(album.artists),
          artistId: primaryArtistId(album.artists),
          thumbnailUrl: art,
          year: album.year,
        ),
      );
    }
    if (result is ArtistDetailed) {
      final artist = result as ArtistDetailed;
      final art = artist.thumbnails.isNotEmpty
          ? artist.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: artist.name,
        imageUrl: art,
        shape: ThumbnailShape.circle,
        onSelect: () => context.push('/artist/${artist.artistId}'),
        onLongSelect: () => ContextMenuSheet.showForArtist(
          context,
          artistId: artist.artistId,
          name: artist.name,
          thumbnailUrl: art,
        ),
      );
    }
    if (result is PlaylistDetailed) {
      final playlist = result as PlaylistDetailed;
      final art = playlist.thumbnails.isNotEmpty
          ? playlist.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: playlist.name,
        subtitle: displayArtists(playlist.artists),
        imageUrl: art,
        onSelect: () => context.push('/playlist/${playlist.playlistId}'),
        onLongSelect: () => ContextMenuSheet.showForPlaylist(
          context,
          playlistId: playlist.playlistId,
          name: playlist.name,
          thumbnailUrl: art,
        ),
      );
    }
    if (result is PodcastDetailed) {
      final podcast = result as PodcastDetailed;
      final art = podcast.thumbnails.isNotEmpty
          ? podcast.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: podcast.name,
        subtitle: podcast.author,
        imageUrl: art,
        onSelect: () => context.push('/podcast/${podcast.browseId}'),
        onLongSelect: () => ContextMenuSheet.showForPodcast(
          context,
          browseId: podcast.browseId,
          name: podcast.name,
          author: podcast.author,
          thumbnailUrl: art,
        ),
      );
    }
    if (result is EpisodeDetailed) {
      final episode = result as EpisodeDetailed;
      final art = episode.thumbnails.isNotEmpty
          ? episode.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: episode.name,
        subtitle: episode.podcastName,
        imageUrl: art,
        onSelect: () => context.push('/episode/${episode.videoId}'),
        onLongSelect: () => ContextMenuSheet.showForEpisode(
          context,
          videoId: episode.videoId,
          name: episode.name,
          podcastName: episode.podcastName,
          podcastBrowseId: episode.podcastId,
          thumbnailUrl: art,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
