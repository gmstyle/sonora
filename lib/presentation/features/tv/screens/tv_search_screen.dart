import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/extensions/stat_format.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../library/providers/library_provider.dart';
import '../../search/library_matches.dart';
import '../../search/providers/library_matches_provider.dart';
import '../../search/providers/search_provider.dart';
import '../../search/search_wide_layout.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_category_card.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_shelf.dart';
import '../widgets/tv_shimmer.dart';

const _kTvQuickGenres = [
  ('Pop', 'Pop'),
  ('Hip Hop', 'Hip Hop'),
  ('Electronic', 'Electronic'),
  ('Rock', 'Rock'),
  ('Chill', 'Relax & Chill'),
  ('R&B', 'R&B'),
  ('Jazz & Blues', 'Jazz & Blues'),
  ('Workout', 'Workout & Focus'),
];

String? _joinMeta(Iterable<String?> parts) {
  final cleaned = [
    for (final part in parts)
      if (part != null && part.isNotEmpty) part,
  ];
  if (cleaned.isEmpty) return null;
  return cleaned.join(' • ');
}

/// TV search: system IME field + filter chips + library matches + poster grid.
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
    final typingQuery = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchFilterProvider);
    final filterLabels = searchFilterLabels(l10n);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.contentPadding,
            TvMetrics.browseTopPadding,
            TvMetrics.contentPadding,
            12,
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
                      enabled: true,
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
              TvFocusable(
                onSelect: () => _submit(_controller.text),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.25),
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
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.search,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
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

        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TvMetrics.contentPadding,
            ),
            itemCount: filterLabels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = filter == index;
              return TvFocusable(
                onSelect: () =>
                    ref.read(searchFilterProvider.notifier).update(index),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : TvColors.surfaceButton,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? colorScheme.primary
                          : TvColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    filterLabels[index],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : TvColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: activeQuery.isEmpty
              ? _TvSearchIdleBody(
                  typingQuery: typingQuery,
                  onSelectGenre: _submit,
                )
              : _TvSearchResultsBody(
                  typingQuery: typingQuery,
                  activeQuery: activeQuery,
                  resultsAsync: resultsAsync,
                  offline: offline,
                ),
        ),
      ],
    );
  }
}

class _TvSearchIdleBody extends ConsumerWidget {
  final String typingQuery;
  final ValueChanged<String> onSelectGenre;

  const _TvSearchIdleBody({
    required this.typingQuery,
    required this.onSelectGenre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = typingQuery.trim();
    final matches = query.isEmpty
        ? LibraryMatches.empty
        : ref.watch(libraryMatchesProvider(query));
    final filter = ref.watch(searchFilterProvider);
    final showLibrary = query.isNotEmpty && !matches.isEmptyFor(filter);

    if (!showLibrary) {
      return _TvSearchGenreDiscovery(onSelectGenre: onSelectGenre);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [_TvLibraryMatchesShelves(matches: matches, filter: filter)],
    );
  }
}

class _TvSearchResultsBody extends ConsumerWidget {
  final String typingQuery;
  final String activeQuery;
  final AsyncValue<List<SearchResult>> resultsAsync;
  final bool offline;

  const _TvSearchResultsBody({
    required this.typingQuery,
    required this.activeQuery,
    required this.resultsAsync,
    required this.offline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final query = typingQuery.trim().isNotEmpty
        ? typingQuery.trim()
        : activeQuery.trim();
    final matches = query.isEmpty
        ? LibraryMatches.empty
        : ref.watch(libraryMatchesProvider(query));
    final filter = ref.watch(searchFilterProvider);
    final showLibrary = !matches.isEmptyFor(filter);

    return resultsAsync.when(
      loading: () => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (showLibrary)
            _TvLibraryMatchesShelves(matches: matches, filter: filter),
          const TvPosterGridShimmer(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(
              horizontal: TvMetrics.contentPadding,
              vertical: 8,
            ),
          ),
        ],
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.noResults,
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
      data: (results) {
        if (!showLibrary && results.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.searchX,
            title: offline ? l10n.yourLibrary : l10n.noResults,
          );
        }
        return CustomScrollView(
          slivers: [
            if (showLibrary)
              SliverToBoxAdapter(
                child: _TvLibraryMatchesShelves(
                  matches: matches,
                  filter: filter,
                ),
              ),
            if (results.isNotEmpty)
              TvPosterSliverGrid(
                itemCount: results.length,
                itemBuilder: (context, index) =>
                    _TvSearchResultCard(result: results[index]),
              )
            else if (showLibrary && offline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(TvMetrics.contentPadding),
                  child: Text(
                    l10n.yourLibrary,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: TvColors.textSecondary),
                  ),
                ),
              )
            else if (!showLibrary)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyStateWidget(
                  icon: LucideIcons.searchX,
                  title: l10n.noResults,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TvLibraryMatchesShelves extends ConsumerWidget {
  final LibraryMatches matches;
  final int filter;

  const _TvLibraryMatchesShelves({required this.matches, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          TvMetrics.contentPadding,
          8,
          TvMetrics.contentPadding,
          4,
        ),
        child: Text(
          l10n.yourLibrary.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: TvColors.textSecondary,
          ),
        ),
      ),
      if (filter == 0 || filter == 1)
        TvShelf(
          title: l10n.songs,
          children: [
            for (final song in matches.songs.take(8))
              TvPosterCard(
                title: song.title,
                subtitle: song.artist,
                imageUrl: song.thumbnailUrl,
                onSelect: () => ref
                    .read(playerStateProvider.notifier)
                    .playVideoId(
                      song.videoId,
                      isVideo: song.isVideo,
                      isExplicit: song.isExplicit,
                    ),
                onLongSelect: () => ContextMenuSheet.showForSong(
                  context,
                  videoId: song.videoId,
                  title: song.title,
                  artist: song.artist,
                  thumbnailUrl: song.thumbnailUrl,
                  duration: song.duration,
                  isVideo: song.isVideo,
                  isExplicit: song.isExplicit,
                  artistId: song.artistId,
                  albumId: song.albumId,
                ),
              ),
          ],
        ),
      if (filter == 0 || filter == 2)
        TvShelf(
          title: l10n.artists,
          children: [
            for (final artist in matches.artists.take(8))
              TvPosterCard(
                title: artist.name,
                imageUrl: artist.thumbnailUrl,
                shape: ThumbnailShape.circle,
                onSelect: () => context.push('/artist/${artist.artistId}'),
                onLongSelect: () => ContextMenuSheet.showForArtist(
                  context,
                  artistId: artist.artistId,
                  name: artist.name,
                  thumbnailUrl: artist.thumbnailUrl,
                ),
              ),
          ],
        ),
      if (filter == 0 || filter == 3)
        TvShelf(
          title: l10n.albums,
          children: [
            for (final album in matches.albums.take(8))
              TvPosterCard(
                title: album.name,
                subtitle: _joinMeta([
                  album.artistName,
                  if (album.year != null) '${album.year}',
                ]),
                imageUrl: album.thumbnailUrl,
                onSelect: () => context.push('/album/${album.albumId}'),
                onLongSelect: () => ContextMenuSheet.showForAlbum(
                  context,
                  albumId: album.albumId,
                  name: album.name,
                  artist: album.artistName,
                  artistId: album.artistId,
                  thumbnailUrl: album.thumbnailUrl,
                  year: album.year,
                ),
              ),
          ],
        ),
      if (filter == 0 || filter == 4) ...[
        TvShelf(
          title: l10n.myPlaylists,
          children: [
            for (final playlist in matches.playlists.take(8))
              TvPosterCard(
                title: playlist.name,
                subtitle: playlist.description,
                placeholderOverride: Container(
                  decoration: BoxDecoration(gradient: brandSpectrumOf(context)),
                  child: const Center(
                    child: Icon(
                      LucideIcons.listMusic,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
                onSelect: () async {
                  final entries = await ref.read(
                    playlistEntriesProvider(playlist.id).future,
                  );
                  if (entries.isEmpty) return;
                  await ref
                      .read(playerStateProvider.notifier)
                      .playLocalPlaylist(entries, startIndex: 0);
                },
                onLongSelect: () => ContextMenuSheet.showForCustomPlaylist(
                  context,
                  playlist: playlist,
                  onUpdated: () => ref.invalidate(playlistsProvider),
                ),
              ),
          ],
        ),
        TvShelf(
          title: l10n.likedPlaylists,
          children: [
            for (final playlist in matches.likedPlaylists.take(8))
              TvPosterCard(
                title: playlist.name,
                subtitle: playlist.videoCount != null
                    ? l10n.videoCount(playlist.videoCount!)
                    : null,
                imageUrl: playlist.thumbnailUrl,
                onSelect: () =>
                    context.push('/playlist/${playlist.playlistId}'),
                onLongSelect: () => ContextMenuSheet.showForPlaylist(
                  context,
                  playlistId: playlist.playlistId,
                  name: playlist.name,
                  thumbnailUrl: playlist.thumbnailUrl,
                ),
              ),
          ],
        ),
      ],
      if (filter == 0 || filter == 5)
        TvShelf(
          title: l10n.podcasts,
          children: [
            for (final podcast in matches.podcasts.take(8))
              TvPosterCard(
                title: podcast.name,
                subtitle: podcast.authorName,
                imageUrl: podcast.thumbnailUrl,
                onSelect: () => context.push('/podcast/${podcast.browseId}'),
                onLongSelect: () => ContextMenuSheet.showForPodcast(
                  context,
                  browseId: podcast.browseId,
                  name: podcast.name,
                  author: podcast.authorName,
                  thumbnailUrl: podcast.thumbnailUrl,
                ),
              ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _TvSearchGenreDiscovery extends StatelessWidget {
  final ValueChanged<String> onSelectGenre;

  const _TvSearchGenreDiscovery({required this.onSelectGenre});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.only(top: TvMetrics.browseTopPadding),
      children: [
        TvShelf(
          title: l10n.moodsAndGenres,
          children: [
            for (var i = 0; i < _kTvQuickGenres.length; i++)
              TvCategoryCard(
                title: switch (i) {
                  4 => l10n.mixMoodChill,
                  7 => l10n.mixMoodWorkout,
                  _ => _kTvQuickGenres[i].$1,
                },
                onSelect: () => onSelectGenre(_kTvQuickGenres[i].$2),
                onLeftAtEdge: i == 0
                    ? () => TvShellFocus.requestSidebar(context)
                    : null,
              ),
          ],
        ),
      ],
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
        subtitle: _joinMeta([
          displayArtists(song.artists),
          statFigure(song.playCount),
        ]),
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
          playCount: song.playCount,
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
        subtitle: _joinMeta([
          displayArtists(video.artists),
          statFigure(video.viewCount),
        ]),
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
          playCount: video.viewCount,
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
        subtitle: _joinMeta([
          displayArtists(album.artists),
          if (album.year != null) '${album.year}',
        ]),
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
        subtitle: statFigure(artist.monthlyListeners),
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
        subtitle: _joinMeta([episode.podcastName, episode.date]),
        imageUrl: art,
        onSelect: () => context.push('/episode/${episode.videoId}'),
        onLongSelect: () => ContextMenuSheet.showForEpisode(
          context,
          videoId: episode.videoId,
          name: episode.name,
          podcastName: episode.podcastName,
          podcastBrowseId: episode.podcastId,
          thumbnailUrl: art,
          date: episode.date,
        ),
      );
    }
    if (result is ProfileDetailed) {
      final profile = result as ProfileDetailed;
      final art = profile.thumbnails.isNotEmpty
          ? profile.thumbnails.last.url
          : null;
      return TvPosterCard(
        title: profile.name,
        subtitle: profile.handle,
        imageUrl: art,
        shape: ThumbnailShape.circle,
        onSelect: () => context.push('/user/${profile.browseId}'),
      );
    }
    return const SizedBox.shrink();
  }
}
