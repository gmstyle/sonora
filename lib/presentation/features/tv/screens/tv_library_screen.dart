import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../library/providers/library_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_shelf.dart';

enum _TvLibrarySection { liked, playlists, artists, albums, podcasts, mixes }

/// TV library: category chips + poster shelves/grids.
class TvLibraryScreen extends ConsumerStatefulWidget {
  const TvLibraryScreen({super.key});

  @override
  ConsumerState<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends ConsumerState<TvLibraryScreen> {
  _TvLibrarySection _section = _TvLibrarySection.liked;
  final FocusNode _firstContentFocus = FocusNode(
    debugLabel: 'libraryFirstItem',
  );

  @override
  void dispose() {
    _firstContentFocus.dispose();
    super.dispose();
  }

  void _focusContent() {
    // Defer so the new section body has mounted and attached its first poster.
    // Guard both `mounted` and a valid context — after a KeyedSubtree key
    // change the old FocusNode is detached for one frame before the new
    // subtree reattaches it; without the context guard requestFocus() silently
    // fails and the grid becomes unreachable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_firstContentFocus.context != null &&
          _firstContentFocus.canRequestFocus) {
        _firstContentFocus.requestFocus();
        return;
      }
      // Fallback: ask the shell's content scope to pick the first visible
      // descendant (covers the case where the node is still attaching).
      TvShellFocus.requestContent(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final likedCount = ref.watch(likedSongsProvider).asData?.value.length;
    final localPlaylistsCount = ref
        .watch(playlistsProvider)
        .asData
        ?.value
        .length;
    final likedPlaylistsCount = ref
        .watch(likedPlaylistsProvider)
        .asData
        ?.value
        .length;
    final playlistsCount =
        localPlaylistsCount != null || likedPlaylistsCount != null
        ? (localPlaylistsCount ?? 0) + (likedPlaylistsCount ?? 0)
        : null;
    final artistsCount = ref
        .watch(followedArtistsProvider)
        .asData
        ?.value
        .length;
    final albumsCount = ref.watch(likedAlbumsProvider).asData?.value.length;
    final podcastsCount = ref.watch(likedPodcastsProvider).asData?.value.length;

    String withCount(String base, int? count) =>
        count != null && count > 0 ? '$base ($count)' : base;

    final labels = {
      _TvLibrarySection.liked: withCount(l10n.favorites, likedCount),
      _TvLibrarySection.playlists: withCount(l10n.playlists, playlistsCount),
      _TvLibrarySection.artists: withCount(l10n.artists, artistsCount),
      _TvLibrarySection.albums: withCount(l10n.albums, albumsCount),
      _TvLibrarySection.podcasts: withCount(l10n.podcasts, podcastsCount),
      _TvLibrarySection.mixes: l10n.yourMixes,
    };

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
              Text(
                l10n.library,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: TvColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final section in _TvLibrarySection.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TvFocusable(
                            onSelect: () {
                              setState(() => _section = section);
                              _focusContent();
                            },
                            onLeftAtEdge: section == _TvLibrarySection.liked
                                ? () => TvShellFocus.requestSidebar(context)
                                : null,
                            onDownAtEdge: _focusContent,
                            borderRadius: BorderRadius.circular(99),
                            child: AnimatedContainer(
                              duration: TvMetrics.drawerAnimDuration,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _section == section
                                    ? colorScheme.primary.withValues(
                                        alpha: 0.18,
                                      )
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _section == section
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.45,
                                        )
                                      : TvColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  labels[section]!,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _section == section
                                        ? colorScheme.primary
                                        : TvColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_section),
            child: switch (_section) {
              _TvLibrarySection.liked => _LikedSongsBody(
                firstFocus: _firstContentFocus,
              ),
              _TvLibrarySection.playlists => _PlaylistsBody(
                firstFocus: _firstContentFocus,
              ),
              _TvLibrarySection.artists => _ArtistsBody(
                firstFocus: _firstContentFocus,
              ),
              _TvLibrarySection.albums => _AlbumsBody(
                firstFocus: _firstContentFocus,
              ),
              _TvLibrarySection.podcasts => _PodcastsBody(
                firstFocus: _firstContentFocus,
              ),
              _TvLibrarySection.mixes => _MixesBody(
                firstFocus: _firstContentFocus,
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _LikedSongsBody extends ConsumerWidget {
  final FocusNode firstFocus;

  const _LikedSongsBody({required this.firstFocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedSongsProvider);
    final l10n = AppLocalizations.of(context)!;
    return async.when(
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: ShimmerLoading(
          variant: ShimmerVariant.mediaGrid,
          gridColumns: 4,
        ),
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadFavorites,
        onRetry: () => ref.invalidate(likedSongsProvider),
      ),
      data: (songs) {
        if (songs.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.heart,
            title: l10n.favorites,
          );
        }
        return TvPosterGrid(
          itemCount: songs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return TvPosterCard(
                title: l10n.favorites,
                subtitle: l10n.catalogSongCount(songs.length),
                focusNode: firstFocus,
                onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                placeholderOverride: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Color(0xFFF43F5E), Color(0xFF4F46E5)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.favorite, size: 42, color: Colors.white),
                  ),
                ),
                onSelect: () => ref
                    .read(playerStateProvider.notifier)
                    .playSmartMix(songs, startIndex: 0),
              );
            }
            final song = songs[index - 1];
            return TvPosterCard(
              title: song.title,
              subtitle: song.artist,
              imageUrl: song.thumbnailUrl,
              onSelect: () => ref
                  .read(playerStateProvider.notifier)
                  .playSmartMix(songs, startIndex: index - 1),
              onLongSelect: () => ContextMenuSheet.showForSong(
                context,
                videoId: song.videoId,
                title: song.title,
                artist: song.artist,
                thumbnailUrl: song.thumbnailUrl,
                duration: song.duration,
                isVideo: song.isVideo,
                isExplicit: song.isExplicit,
                artistsJson: song.artistsJson,
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaylistsBody extends ConsumerWidget {
  final FocusNode firstFocus;

  const _PlaylistsBody({required this.firstFocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAsync = ref.watch(playlistsProvider);
    final likedAsync = ref.watch(likedPlaylistsProvider);
    final l10n = AppLocalizations.of(context)!;

    if (localAsync.isLoading || likedAsync.isLoading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(TvMetrics.contentPadding),
        child: ShimmerLoading(variant: ShimmerVariant.section),
      );
    }
    if (localAsync.hasError) {
      return ErrorRetryWidget(
        message: l10n.failedToLoadPlaylists,
        onRetry: () => ref.invalidate(playlistsProvider),
      );
    }

    final local = localAsync.asData?.value ?? const [];
    final liked = likedAsync.asData?.value ?? const [];
    var firstAssigned = false;

    FocusNode? takeFirst() {
      if (firstAssigned) return null;
      firstAssigned = true;
      return firstFocus;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        TvShelf(
          title: l10n.yourPlaylists,
          children: [
            for (var i = 0; i < local.length; i++)
              TvPosterCard(
                title: local[i].name,
                focusNode: i == 0 ? takeFirst() : null,
                placeholderOverride: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.listMusic,
                      size: 36,
                      color: SonoraPulseTokens.onBrandGraphic,
                    ),
                  ),
                ),
                onLeftAtEdge: i == 0
                    ? () => TvShellFocus.requestSidebar(context)
                    : null,
                onSelect: () async {
                  final entries = await ref.read(
                    playlistEntriesProvider(local[i].id).future,
                  );
                  if (entries.isEmpty) return;
                  await ref
                      .read(playerStateProvider.notifier)
                      .playLocalPlaylist(entries, startIndex: 0);
                },
                onLongSelect: () => ContextMenuSheet.showForCustomPlaylist(
                  context,
                  playlist: local[i],
                  onUpdated: () {},
                ),
              ),
          ],
        ),
        TvShelf(
          title: l10n.playlists,
          children: [
            for (var i = 0; i < liked.length; i++)
              TvPosterCard(
                title: liked[i].name,
                imageUrl: liked[i].thumbnailUrl,
                focusNode: takeFirst(),
                onSelect: () =>
                    context.push('/playlist/${liked[i].playlistId}'),
                onLongSelect: () => ContextMenuSheet.showForPlaylist(
                  context,
                  playlistId: liked[i].playlistId,
                  name: liked[i].name,
                  thumbnailUrl: liked[i].thumbnailUrl,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ArtistsBody extends ConsumerWidget {
  final FocusNode firstFocus;

  const _ArtistsBody({required this.firstFocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followedArtistsProvider);
    final l10n = AppLocalizations.of(context)!;
    return async.when(
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: ShimmerLoading(
          variant: ShimmerVariant.mediaGrid,
          gridColumns: 4,
        ),
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadArtists,
        onRetry: () => ref.invalidate(followedArtistsProvider),
      ),
      data: (artists) {
        if (artists.isEmpty) {
          return EmptyStateWidget(icon: LucideIcons.user, title: l10n.artists);
        }
        return TvPosterGrid(
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return TvPosterCard(
              title: artist.name,
              imageUrl: artist.thumbnailUrl,
              shape: ThumbnailShape.circle,
              focusNode: index == 0 ? firstFocus : null,
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => context.push('/artist/${artist.artistId}'),
              onLongSelect: () => ContextMenuSheet.showForArtist(
                context,
                artistId: artist.artistId,
                name: artist.name,
                thumbnailUrl: artist.thumbnailUrl,
              ),
            );
          },
        );
      },
    );
  }
}

class _AlbumsBody extends ConsumerWidget {
  final FocusNode firstFocus;

  const _AlbumsBody({required this.firstFocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedAlbumsProvider);
    final l10n = AppLocalizations.of(context)!;
    return async.when(
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: ShimmerLoading(
          variant: ShimmerVariant.mediaGrid,
          gridColumns: 4,
        ),
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadAlbums,
        onRetry: () => ref.invalidate(likedAlbumsProvider),
      ),
      data: (albums) {
        if (albums.isEmpty) {
          return EmptyStateWidget(icon: LucideIcons.disc3, title: l10n.albums);
        }
        return TvPosterGrid(
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return TvPosterCard(
              title: album.name,
              subtitle: album.artistName,
              imageUrl: album.thumbnailUrl,
              focusNode: index == 0 ? firstFocus : null,
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
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
            );
          },
        );
      },
    );
  }
}

class _PodcastsBody extends ConsumerWidget {
  final FocusNode firstFocus;

  const _PodcastsBody({required this.firstFocus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedPodcastsProvider);
    final l10n = AppLocalizations.of(context)!;
    return async.when(
      loading: () => const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: ShimmerLoading(
          variant: ShimmerVariant.mediaGrid,
          gridColumns: 4,
        ),
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadPodcast,
        onRetry: () => ref.invalidate(likedPodcastsProvider),
      ),
      data: (podcasts) {
        if (podcasts.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.podcast,
            title: l10n.podcasts,
          );
        }
        return TvPosterGrid(
          itemCount: podcasts.length,
          itemBuilder: (context, index) {
            final podcast = podcasts[index];
            return TvPosterCard(
              title: podcast.name,
              subtitle: podcast.authorName,
              imageUrl: podcast.thumbnailUrl,
              focusNode: index == 0 ? firstFocus : null,
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => context.push('/podcast/${podcast.browseId}'),
              onLongSelect: () => ContextMenuSheet.showForPodcast(
                context,
                browseId: podcast.browseId,
                name: podcast.name,
                author: podcast.authorName,
                thumbnailUrl: podcast.thumbnailUrl,
              ),
            );
          },
        );
      },
    );
  }
}

class _MixesBody extends StatelessWidget {
  final FocusNode firstFocus;

  const _MixesBody({required this.firstFocus});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      children: [
        TvShelf(
          title: l10n.yourMixes,
          children: [
            for (var i = 0; i < SmartMixType.values.length; i++)
              TvPosterCard(
                title: switch (SmartMixType.values[i]) {
                  SmartMixType.mostPlayed => l10n.mostPlayed,
                  SmartMixType.recentlyPlayed => l10n.recentlyPlayed,
                  SmartMixType.forgottenFavorites => l10n.forgottenFavorites,
                },
                placeholderOverride: Container(
                  decoration: BoxDecoration(
                    gradient: smartMixGradient(context, SmartMixType.values[i]),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 36,
                      color: SonoraPulseTokens.onBrandGraphic,
                    ),
                  ),
                ),
                focusNode: i == 0 ? firstFocus : null,
                onLeftAtEdge: i == 0
                    ? () => TvShellFocus.requestSidebar(context)
                    : null,
                onSelect: () =>
                    context.push('/smart-mix/${SmartMixType.values[i].name}'),
              ),
          ],
        ),
      ],
    );
  }
}
