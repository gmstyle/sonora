import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../widgets/tv_shelf.dart';

enum _TvLibrarySection { liked, playlists, artists, albums, podcasts, mixes }

const _kTvGrid = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: TvMetrics.shelfCardWidth + 48,
  mainAxisExtent: TvMetrics.shelfRowHeight + 8,
  crossAxisSpacing: 24,
  mainAxisSpacing: 24,
);

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
    // Defer so the new section body has mounted its first poster.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_firstContentFocus.canRequestFocus) {
        _firstContentFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labels = {
      _TvLibrarySection.liked: l10n.favorites,
      _TvLibrarySection.playlists: l10n.playlists,
      _TvLibrarySection.artists: l10n.artists,
      _TvLibrarySection.albums: l10n.albums,
      _TvLibrarySection.podcasts: l10n.podcasts,
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
            8,
          ),
          child: Text(
            l10n.library,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TvMetrics.contentPadding,
            ),
            children: [
              for (final section in _TvLibrarySection.values)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: TvFocusable(
                    onSelect: () {
                      setState(() => _section = section);
                      _focusContent();
                    },
                    onLeftAtEdge: section == _TvLibrarySection.liked
                        ? () => TvShellFocus.requestSidebar(context)
                        : null,
                    onDownAtEdge: _focusContent,
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: TvMetrics.drawerAnimDuration,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _section == section
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        labels[section]!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: _section == section
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _section == section
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
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
      loading: () => const ShimmerLoading(variant: ShimmerVariant.mediaGrid),
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
        return GridView.builder(
          padding: const EdgeInsets.all(TvMetrics.contentPadding),
          gridDelegate: _kTvGrid,
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return TvPosterCard(
              title: song.title,
              subtitle: song.artist,
              imageUrl: song.thumbnailUrl,
              focusNode: index == 0 ? firstFocus : null,
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => ref
                  .read(playerStateProvider.notifier)
                  .playVideoId(song.videoId, isVideo: song.isVideo),
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
      return const ShimmerLoading(variant: ShimmerVariant.section);
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

    return ListView(
      children: [
        TvShelf(
          title: l10n.yourPlaylists,
          children: [
            for (var i = 0; i < local.length; i++)
              TvPosterCard(
                title: local[i].name,
                focusNode: i == 0 ? takeFirst() : null,
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
      loading: () => const ShimmerLoading(variant: ShimmerVariant.mediaGrid),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadArtists,
        onRetry: () => ref.invalidate(followedArtistsProvider),
      ),
      data: (artists) {
        if (artists.isEmpty) {
          return EmptyStateWidget(icon: LucideIcons.user, title: l10n.artists);
        }
        return GridView.builder(
          padding: const EdgeInsets.all(TvMetrics.contentPadding),
          gridDelegate: _kTvGrid,
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
      loading: () => const ShimmerLoading(variant: ShimmerVariant.mediaGrid),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadAlbums,
        onRetry: () => ref.invalidate(likedAlbumsProvider),
      ),
      data: (albums) {
        if (albums.isEmpty) {
          return EmptyStateWidget(icon: LucideIcons.disc3, title: l10n.albums);
        }
        return GridView.builder(
          padding: const EdgeInsets.all(TvMetrics.contentPadding),
          gridDelegate: _kTvGrid,
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
      loading: () => const ShimmerLoading(variant: ShimmerVariant.mediaGrid),
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
        return GridView.builder(
          padding: const EdgeInsets.all(TvMetrics.contentPadding),
          gridDelegate: _kTvGrid,
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
