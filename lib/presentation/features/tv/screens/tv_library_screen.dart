import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../library/providers/library_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_shelf.dart';

enum _TvLibrarySection { liked, playlists, artists, albums, podcasts, mixes }

const _kTvGrid = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: TvMetrics.shelfCardWidth + 24,
  mainAxisExtent: TvMetrics.shelfRowHeight,
  crossAxisSpacing: 16,
  mainAxisSpacing: 16,
);

/// TV library: category chips + poster shelves/grids.
class TvLibraryScreen extends ConsumerStatefulWidget {
  const TvLibraryScreen({super.key});

  @override
  ConsumerState<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends ConsumerState<TvLibraryScreen> {
  _TvLibrarySection _section = _TvLibrarySection.liked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            28,
            TvMetrics.contentPadding,
            8,
          ),
          child: Text(
            l10n.library,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 56,
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
                    onSelect: () => setState(() => _section = section),
                    onLeftAtEdge: section == _TvLibrarySection.liked
                        ? () => TvShellFocus.requestSidebar(context)
                        : null,
                    borderRadius: BorderRadius.circular(24),
                    child: FilterChip(
                      label: Text(labels[section]!),
                      selected: _section == section,
                      onSelected: (_) => setState(() => _section = section),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            _TvLibrarySection.liked => const _LikedSongsBody(),
            _TvLibrarySection.playlists => const _PlaylistsBody(),
            _TvLibrarySection.artists => const _ArtistsBody(),
            _TvLibrarySection.albums => const _AlbumsBody(),
            _TvLibrarySection.podcasts => const _PodcastsBody(),
            _TvLibrarySection.mixes => const _MixesBody(),
          },
        ),
      ],
    );
  }
}

class _LikedSongsBody extends ConsumerWidget {
  const _LikedSongsBody();

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
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => ref
                  .read(playerStateProvider.notifier)
                  .playVideoId(song.videoId, isVideo: song.isVideo),
            );
          },
        );
      },
    );
  }
}

class _PlaylistsBody extends ConsumerWidget {
  const _PlaylistsBody();

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

    return ListView(
      children: [
        TvShelf(
          title: l10n.yourPlaylists,
          children: [
            for (var i = 0; i < local.length; i++)
              TvPosterCard(
                title: local[i].name,
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
              ),
          ],
        ),
        TvShelf(
          title: l10n.playlists,
          children: [
            for (final pl in liked)
              TvPosterCard(
                title: pl.name,
                imageUrl: pl.thumbnailUrl,
                onSelect: () => context.push('/playlist/${pl.playlistId}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ArtistsBody extends ConsumerWidget {
  const _ArtistsBody();

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
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => context.push('/artist/${artist.artistId}'),
            );
          },
        );
      },
    );
  }
}

class _AlbumsBody extends ConsumerWidget {
  const _AlbumsBody();

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
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => context.push('/album/${album.albumId}'),
            );
          },
        );
      },
    );
  }
}

class _PodcastsBody extends ConsumerWidget {
  const _PodcastsBody();

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
              onLeftAtEdge: index == 0
                  ? () => TvShellFocus.requestSidebar(context)
                  : null,
              onSelect: () => context.push('/podcast/${podcast.browseId}'),
            );
          },
        );
      },
    );
  }
}

class _MixesBody extends StatelessWidget {
  const _MixesBody();

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
