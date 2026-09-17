import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/stat_format.dart';

import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/album_tile.dart';
import '../../shared/widgets/artist_card.dart';
import '../../shared/widgets/artist_tile.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/filter_chip_bar.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/playlist_tile.dart';
import '../../shared/widgets/search_suggestion_tile.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../../shared/widgets/explicit_badge.dart';
import 'providers/search_provider.dart';
import '../../../core/utils/artists_utils.dart';

/// Content max width for Search on wide shells (≥ [kExpandedBreakpoint]).
const double _kSearchContentMaxWidth = 1100;
const double _kSearchFilterColumnWidth = 168;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).update(query);
  }

  void _submitSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchQueryProvider.notifier).update(query);
    ref.read(activeSearchQueryProvider.notifier).submit(query);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(activeSearchQueryProvider.notifier).update('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final activeQuery = ref.watch(activeSearchQueryProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: false,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              suffixIcon:
                  query.isNotEmpty
                      ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: _clearSearch,
                      )
                      : null,
            ),
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: _onSearchChanged,
            onSubmitted: _submitSearch,
          ),
        ),
      ),
      body: _buildBody(query, activeQuery),
    );
  }

  Widget _buildBody(String query, String activeQuery) {
    if (query.isEmpty && activeQuery.isEmpty) {
      return _RecentSearches(onTapSearch: _submitSearch);
    }
    if (query.isNotEmpty && query != activeQuery) {
      return _Suggestions(
        query: query,
        onTapSuggestion: _submitSearch,
        onInsertSuggestion: (val) {
          _searchController.text = val;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: val.length),
          );
          ref.read(searchQueryProvider.notifier).update(val);
          _focusNode.requestFocus();
        },
      );
    }
    return _SearchResults(activeQuery: activeQuery);
  }
}

class _RecentSearches extends ConsumerWidget {
  final ValueChanged<String> onTapSearch;

  const _RecentSearches({required this.onTapSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (searches) {
        if (searches.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.search,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.searchForMusic,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.searchForMusicHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppLocalizations.of(context)!.recentSearches,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: searches.length,
                itemBuilder: (context, index) {
                  final s = searches[index];
                  return SearchSuggestionTile(
                    query: s.query,
                    isHistory: true,
                    onTap: () => onTapSearch(s.query),
                    onDelete: () async {
                      await ref
                          .read(libraryNotifierProvider.notifier)
                          .deleteSearchEntry(s.query);
                      ref.invalidate(recentSearchesProvider);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Suggestions extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onTapSuggestion;
  final ValueChanged<String> onInsertSuggestion;

  const _Suggestions({
    required this.query,
    required this.onTapSuggestion,
    required this.onInsertSuggestion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(searchSuggestionsProvider);
    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return SearchSuggestionTile(
              query: suggestion,
              isHistory: false,
              onTap: () => onTapSuggestion(suggestion),
              onInsert: () => onInsertSuggestion(suggestion),
            );
          },
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String activeQuery;

  const _SearchResults({required this.activeQuery});

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLocalizations.of(context)!.showMore,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopResultCard(
    BuildContext context,
    WidgetRef ref,
    SearchResult result,
  ) {
    String title = '';
    String subtitle = '';
    String type = '';
    String? imageUrl;
    VoidCallback? onTap;

    if (result is SongDetailed) {
      title = result.name;
      subtitle = displayArtists(result.artists);
      type = AppLocalizations.of(context)!.songs;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap =
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                result.videoId,
                isVideo: false,
                isExplicit: result.isExplicit,
              );
    } else if (result is VideoDetailed) {
      title = result.name;
      subtitle = displayArtists(result.artists);
      type = AppLocalizations.of(context)!.videos;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap =
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                result.videoId,
                isVideo: true,
                isExplicit: result.isExplicit,
              );
    } else if (result is ArtistDetailed) {
      title = result.name;
      subtitle =
          result.monthlyListeners != null
              ? (stripYtLabel(result.monthlyListeners) ?? '')
              : '';
      type = AppLocalizations.of(context)!.searchArtists;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/artist/${result.artistId}');
    } else if (result is AlbumDetailed) {
      title = result.name;
      subtitle = displayArtists(result.artists);
      type = AppLocalizations.of(context)!.searchAlbums;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/album/${result.albumId}');
    } else if (result is PlaylistDetailed) {
      title = result.name;
      subtitle = displayArtists(result.artists);
      type = AppLocalizations.of(context)!.searchPlaylists;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/playlist/${result.playlistId}');
    } else if (result is PodcastDetailed) {
      title = result.name;
      subtitle = result.author ?? '';
      type = AppLocalizations.of(context)!.podcasts;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/podcast/${result.browseId}');
    } else if (result is EpisodeDetailed) {
      title = result.name;
      subtitle = [
        if (result.podcastName != null) result.podcastName!,
        if (result.date != null) result.date!,
      ].join(' · ');
      type = AppLocalizations.of(context)!.episodes;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/episode/${result.videoId}');
    } else if (result is ProfileDetailed) {
      title = result.name;
      subtitle = result.handle ?? '';
      type = AppLocalizations.of(context)!.profiles;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/user/${result.browseId}');
    }

    final bool isCircle = result is ArtistDetailed || result is ProfileDetailed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              ThumbnailWidget(
                imageUrl: imageUrl,
                size: 72,
                shape:
                    isCircle ? ThumbnailShape.circle : ThumbnailShape.rounded,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((result is SongDetailed && result.isExplicit) ||
                            (result is VideoDetailed && result.isExplicit)) ...[
                          const SizedBox(width: 6),
                          const ExplicitBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                result is PodcastDetailed ||
                        result is ProfileDetailed ||
                        result is ArtistDetailed ||
                        result is AlbumDetailed ||
                        result is PlaylistDetailed
                    ? LucideIcons.chevronRight
                    : LucideIcons.playCircle,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _filterOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.all,
      l10n.songs,
      l10n.searchArtists,
      l10n.searchAlbums,
      l10n.searchPlaylists,
      l10n.searchPodcasts,
      l10n.searchEpisodes,
      l10n.searchProfiles,
    ];
  }

  Widget _buildCardGrid({
    required int itemCount,
    required double childAspectRatio,
    required Widget Function(BuildContext context, int index, double cardWidth)
    itemBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final cardWidth = (constraints.maxWidth - gap) / 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: itemCount,
            itemBuilder:
                (context, index) => itemBuilder(context, index, cardWidth),
          );
        },
      ),
    );
  }

  Widget _buildArtistsShelf(
    BuildContext context,
    List<ArtistDetailed> artists, {
    required bool dense,
  }) {
    final count = artists.length > 8 ? 8 : artists.length;
    if (dense) {
      return _buildCardGrid(
        itemCount: count,
        childAspectRatio: 0.78,
        itemBuilder: (context, idx, cardWidth) {
          final a = artists[idx];
          return ArtistCard(
            artistId: a.artistId,
            name: a.name,
            thumbnailUrl:
                a.thumbnails.isNotEmpty ? a.thumbnails.last.url : null,
            monthlyListeners: a.monthlyListeners,
            cardWidth: cardWidth,
          );
        },
      );
    }
    return SizedBox(
      height: 155,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (context, idx) {
          final a = artists[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ArtistCard(
              artistId: a.artistId,
              name: a.name,
              thumbnailUrl:
                  a.thumbnails.isNotEmpty ? a.thumbnails.last.url : null,
              monthlyListeners: a.monthlyListeners,
              cardWidth: 100,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumsShelf(
    BuildContext context,
    List<AlbumDetailed> albums, {
    required bool dense,
  }) {
    final count = albums.length > 8 ? 8 : albums.length;
    if (dense) {
      return _buildCardGrid(
        itemCount: count,
        childAspectRatio: 0.72,
        itemBuilder: (context, idx, cardWidth) {
          final al = albums[idx];
          return AlbumCard(
            albumId: al.albumId,
            name: al.name,
            artist: displayArtists(al.artists),
            artistId: primaryArtistId(al.artists),
            thumbnailUrl:
                al.thumbnails.isNotEmpty ? al.thumbnails.last.url : null,
            year: al.year,
            cardWidth: cardWidth,
            heroTag: 'search_album_${al.albumId}',
          );
        },
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (context, idx) {
          final al = albums[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AlbumCard(
              albumId: al.albumId,
              name: al.name,
              artist: displayArtists(al.artists),
              artistId: primaryArtistId(al.artists),
              thumbnailUrl:
                  al.thumbnails.isNotEmpty ? al.thumbnails.last.url : null,
              year: al.year,
              cardWidth: 120,
              heroTag: 'search_album_${al.albumId}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsShelf(
    BuildContext context,
    List<PlaylistDetailed> playlists, {
    required bool dense,
  }) {
    final count = playlists.length > 8 ? 8 : playlists.length;
    if (dense) {
      return _buildCardGrid(
        itemCount: count,
        childAspectRatio: 0.68,
        itemBuilder: (context, idx, cardWidth) {
          final pl = playlists[idx];
          return PlaylistCard(
            playlistId: pl.playlistId,
            name: pl.name,
            artist: displayArtists(pl.artists),
            thumbnailUrl:
                pl.thumbnails.isNotEmpty ? pl.thumbnails.last.url : null,
            cardWidth: cardWidth,
            heroTag: 'search_playlist_${pl.playlistId}',
          );
        },
      );
    }
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (context, idx) {
          final pl = playlists[idx];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PlaylistCard(
              playlistId: pl.playlistId,
              name: pl.name,
              artist: displayArtists(pl.artists),
              thumbnailUrl:
                  pl.thumbnails.isNotEmpty ? pl.thumbnails.last.url : null,
              cardWidth: 120,
              heroTag: 'search_playlist_${pl.playlistId}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsContent(
    BuildContext context,
    WidgetRef ref, {
    required int filter,
    required AsyncValue<List<SearchResult>> resultsAsync,
    required bool denseAllSections,
  }) {
    return resultsAsync.when(
      loading:
          () => ListView.builder(
            itemCount: 6,
            itemBuilder:
                (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
          ),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.searchFailed,
            onRetry: () => ref.invalidate(searchResultsProvider),
          ),
      data: (results) {
        if (results.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.searchX,
            title: AppLocalizations.of(context)!.noResults,
            body: AppLocalizations.of(context)!.noResultsHint,
          );
        }

        if (filter > 0) {
          return ListView.builder(
            padding: EdgeInsets.only(
              top: 4,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            itemCount: results.length,
            itemBuilder:
                (context, index) =>
                    _buildResultItem(context, ref, results[index]),
          );
        }

        final songs = results.whereType<SongDetailed>().toList();
        final videos = results.whereType<VideoDetailed>().toList();
        final artists = results.whereType<ArtistDetailed>().toList();
        final albums = results.whereType<AlbumDetailed>().toList();
        final playlists = results.whereType<PlaylistDetailed>().toList();
        final podcasts = results.whereType<PodcastDetailed>().toList();
        final episodes = results.whereType<EpisodeDetailed>().toList();
        final profiles = results.whereType<ProfileDetailed>().toList();

        return ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            _buildSectionHeader(
              context,
              title: AppLocalizations.of(context)!.topResult,
            ),
            _buildTopResultCard(context, ref, results.first),

            if (songs.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.songs,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(1),
              ),
              ...songs.take(4).map((s) => _buildResultItem(context, ref, s)),
            ],

            if (videos.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.videos,
              ),
              ...videos.take(3).map((v) => _buildResultItem(context, ref, v)),
            ],

            if (artists.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.searchArtists,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(2),
              ),
              _buildArtistsShelf(context, artists, dense: denseAllSections),
            ],

            if (albums.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.searchAlbums,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(3),
              ),
              _buildAlbumsShelf(context, albums, dense: denseAllSections),
            ],

            if (playlists.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.searchPlaylists,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(4),
              ),
              _buildPlaylistsShelf(context, playlists, dense: denseAllSections),
            ],

            if (podcasts.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.podcasts,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(5),
              ),
              ...podcasts.take(4).map((p) => _buildResultItem(context, ref, p)),
            ],

            if (episodes.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.episodes,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(6),
              ),
              ...episodes.take(4).map((e) => _buildResultItem(context, ref, e)),
            ],

            if (profiles.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: AppLocalizations.of(context)!.profiles,
                onSeeAll:
                    () => ref.read(searchFilterProvider.notifier).update(7),
              ),
              ...profiles.take(4).map((p) => _buildResultItem(context, ref, p)),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final options = _filterOptions(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kExpandedBreakpoint;
        final resultsContent = _buildResultsContent(
          context,
          ref,
          filter: filter,
          resultsAsync: resultsAsync,
          denseAllSections: isWide,
        );

        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _kSearchContentMaxWidth,
                maxHeight: constraints.maxHeight,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _kSearchFilterColumnWidth,
                    child: FilterChipBar(
                      direction: Axis.vertical,
                      options: options,
                      selectedIndex: filter,
                      onSelected:
                          (index) => ref
                              .read(searchFilterProvider.notifier)
                              .update(index),
                    ),
                  ),
                  Expanded(child: resultsContent),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            FilterChipBar(
              options: options,
              selectedIndex: filter,
              onSelected:
                  (index) =>
                      ref.read(searchFilterProvider.notifier).update(index),
            ),
            Expanded(child: resultsContent),
          ],
        );
      },
    );
  }

  Widget _buildResultItem(
    BuildContext context,
    WidgetRef ref,
    SearchResult result,
  ) {
    if (result is SongDetailed) {
      return SongTile(
        videoId: result.videoId,
        title: result.name,
        artist: displayArtists(result.artists),
        artists: result.artists,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        duration: result.duration,
        albumName: result.album?.name,
        albumId: result.album?.albumId,
        artistId: primaryArtistId(result.artists),
        playCount: result.playCount,
        isExplicit: result.isExplicit,
      );
    }
    if (result is VideoDetailed) {
      return SongTile(
        videoId: result.videoId,
        title: result.name,
        artist: displayArtists(result.artists),
        artists: result.artists,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        duration: result.duration,
        isVideo: true,
        playCount: result.viewCount,
        artistId: primaryArtistId(result.artists),
        isExplicit: result.isExplicit,
      );
    }
    if (result is ArtistDetailed) {
      return ArtistTile(
        artistId: result.artistId,
        name: result.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        monthlyListeners: result.monthlyListeners,
      );
    }
    if (result is AlbumDetailed) {
      return AlbumTile(
        albumId: result.albumId,
        name: result.name,
        artist: displayArtists(result.artists),
        artistId: primaryArtistId(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        year: result.year,
      );
    }
    if (result is PlaylistDetailed) {
      return PlaylistTile(
        playlistId: result.playlistId,
        name: result.name,
        artist: displayArtists(result.artists),
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
      );
    }
    if (result is PodcastDetailed) {
      return ListTile(
        leading: ThumbnailWidget(
          imageUrl:
              result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
          size: 48,
          shape: ThumbnailShape.rounded,
        ),
        title: Text(result.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (result.author != null && result.author!.isNotEmpty)
              result.author!,
            AppLocalizations.of(context)!.podcasts,
          ].join(' · '),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => context.push('/podcast/${result.browseId}'),
      );
    }
    if (result is EpisodeDetailed) {
      return SongTile(
        videoId: result.videoId,
        title: result.name,
        artist: result.podcastName ?? AppLocalizations.of(context)!.episodes,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        playCount: result.date,
        isVideo: false,
        onTap: () => context.push('/episode/${result.videoId}'),
      );
    }
    if (result is ProfileDetailed) {
      return ListTile(
        leading: ThumbnailWidget(
          imageUrl:
              result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
          size: 48,
          shape: ThumbnailShape.circle,
        ),
        title: Text(result.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          result.handle ?? AppLocalizations.of(context)!.profiles,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => context.push('/user/${result.browseId}'),
      );
    }
    return const SizedBox.shrink();
  }
}
