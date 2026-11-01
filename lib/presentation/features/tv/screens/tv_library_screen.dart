import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../library/providers/library_provider.dart';
import '../../library/widgets/playlist_detail_view.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

enum _TvLibrarySection { songs, albums, artists, playlists, podcasts }

/// TV library with a section rail and a poster grid.
class TvLibraryScreen extends ConsumerStatefulWidget {
  const TvLibraryScreen({super.key});

  @override
  ConsumerState<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends ConsumerState<TvLibraryScreen> {
  _TvLibrarySection _section = _TvLibrarySection.songs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: DpadRegion(
              memoryKey: 'tv/library/sections',
              debugLabel: 'tv/library/sections',
              horizontalEdge: DpadEdgeBehavior.stop,
              verticalEdge: DpadEdgeBehavior.stop,
              onEdge: (direction) {
                if (direction == TraversalDirection.left) {
                  TvShellFocus.requestSidebar(context);
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 8, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(
                      l10n.library,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final section in _TvLibrarySection.values)
                    _SectionTile(
                      label: _label(l10n, section),
                      icon: _icon(section),
                      selected: _section == section,
                      entry: section == _section,
                      onSelect: () => setState(() => _section = section),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(child: _buildContent(l10n)),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, _TvLibrarySection section) {
    return switch (section) {
      _TvLibrarySection.songs => l10n.favorites,
      _TvLibrarySection.albums => l10n.albums,
      _TvLibrarySection.artists => l10n.artists,
      _TvLibrarySection.playlists => l10n.playlists,
      _TvLibrarySection.podcasts => l10n.podcasts,
    };
  }

  IconData _icon(_TvLibrarySection section) {
    return switch (section) {
      _TvLibrarySection.songs => LucideIcons.heart,
      _TvLibrarySection.albums => LucideIcons.disc3,
      _TvLibrarySection.artists => LucideIcons.user,
      _TvLibrarySection.playlists => LucideIcons.listMusic,
      _TvLibrarySection.podcasts => LucideIcons.podcast,
    };
  }

  Widget _buildContent(AppLocalizations l10n) {
    return switch (_section) {
      _TvLibrarySection.songs => _songsGrid(l10n),
      _TvLibrarySection.albums => _albumsGrid(l10n),
      _TvLibrarySection.artists => _artistsGrid(l10n),
      _TvLibrarySection.playlists => _playlistsGrid(l10n),
      _TvLibrarySection.podcasts => _podcastsGrid(l10n),
    };
  }

  Widget _songsGrid(AppLocalizations l10n) {
    final async = ref.watch(likedSongsProvider);
    return async.when(
      loading:
          () => const Center(
            child: ShimmerLoading(variant: ShimmerVariant.section),
          ),
      error:
          (_, _) => ErrorRetryWidget(
            message: l10n.failedToLoadFavorites,
            onRetry: () => ref.invalidate(likedSongsProvider),
          ),
      data: (songs) {
        if (songs.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.heart,
            title: l10n.noFavoritesYet,
          );
        }
        return _grid(
          memoryKey: 'tv/library/songs',
          itemCount: songs.length,
          builder: (context, index) {
            final song = songs[index];
            return TvPosterCard(
              title: song.title,
              subtitle: song.artist,
              thumbnailUrl: song.thumbnailUrl,

              onSelect:
                  () => ref
                      .read(playerStateProvider.notifier)
                      .playVideoId(song.videoId, isVideo: song.isVideo),
            );
          },
        );
      },
    );
  }

  Widget _albumsGrid(AppLocalizations l10n) {
    final async = ref.watch(likedAlbumsProvider);
    return async.when(
      loading:
          () => const Center(
            child: ShimmerLoading(variant: ShimmerVariant.section),
          ),
      error:
          (_, _) => ErrorRetryWidget(
            message: l10n.failedToLoadAlbums,
            onRetry: () => ref.invalidate(likedAlbumsProvider),
          ),
      data: (albums) {
        if (albums.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.disc3,
            title: l10n.noLikedAlbums,
          );
        }
        return _grid(
          memoryKey: 'tv/library/albums',
          itemCount: albums.length,
          builder: (context, index) {
            final album = albums[index];
            return TvPosterCard(
              title: album.name,
              subtitle: album.artistName,
              thumbnailUrl: album.thumbnailUrl,

              onSelect: () => context.push('/album/${album.albumId}'),
            );
          },
        );
      },
    );
  }

  Widget _artistsGrid(AppLocalizations l10n) {
    final async = ref.watch(followedArtistsProvider);
    return async.when(
      loading:
          () => const Center(
            child: ShimmerLoading(variant: ShimmerVariant.section),
          ),
      error:
          (_, _) => ErrorRetryWidget(
            message: l10n.failedToLoadArtists,
            onRetry: () => ref.invalidate(followedArtistsProvider),
          ),
      data: (artists) {
        if (artists.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.user,
            title: l10n.noFollowedArtists,
          );
        }
        return _grid(
          memoryKey: 'tv/library/artists',
          itemCount: artists.length,
          mainAxisExtent: 240,
          builder: (context, index) {
            final artist = artists[index];
            return TvPosterCard(
              title: artist.name,
              thumbnailUrl: artist.thumbnailUrl,
              circular: true,
              width: 160,

              onSelect: () => context.push('/artist/${artist.artistId}'),
            );
          },
        );
      },
    );
  }

  Widget _playlistsGrid(AppLocalizations l10n) {
    final localAsync = ref.watch(playlistsProvider);
    final likedAsync = ref.watch(likedPlaylistsProvider);
    if (localAsync.isLoading || likedAsync.isLoading) {
      return const Center(
        child: ShimmerLoading(variant: ShimmerVariant.section),
      );
    }
    if (localAsync.hasError || likedAsync.hasError) {
      return ErrorRetryWidget(
        message: l10n.failedToLoadPlaylists,
        onRetry: () {
          ref.invalidate(playlistsProvider);
          ref.invalidate(likedPlaylistsProvider);
        },
      );
    }
    final local = localAsync.asData?.value ?? const <LocalPlaylistModel>[];
    final liked = likedAsync.asData?.value ?? const <LikedPlaylistModel>[];
    final total = local.length + liked.length;
    if (total == 0) {
      return EmptyStateWidget(
        icon: LucideIcons.listMusic,
        title: l10n.noLocalPlaylistsYet,
      );
    }
    return _grid(
      memoryKey: 'tv/library/playlists',
      itemCount: total,
      builder: (context, index) {
        if (index < local.length) {
          final playlist = local[index];
          return TvPosterCard(
            title: playlist.name,

            onSelect: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => PlaylistDetailView(
                        playlist: playlist,
                        onUpdated: () {},
                      ),
                ),
              );
            },
          );
        }
        final playlist = liked[index - local.length];
        return TvPosterCard(
          title: playlist.name,
          thumbnailUrl: playlist.thumbnailUrl,

          onSelect: () => context.push('/playlist/${playlist.playlistId}'),
        );
      },
    );
  }

  Widget _podcastsGrid(AppLocalizations l10n) {
    final async = ref.watch(likedPodcastsProvider);
    return async.when(
      loading:
          () => const Center(
            child: ShimmerLoading(variant: ShimmerVariant.section),
          ),
      error:
          (_, _) => ErrorRetryWidget(
            message: l10n.failedToLoadPodcast,
            onRetry: () => ref.invalidate(likedPodcastsProvider),
          ),
      data: (podcasts) {
        if (podcasts.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.podcast,
            title: l10n.noLikedPodcasts,
          );
        }
        return _grid(
          memoryKey: 'tv/library/podcasts',
          itemCount: podcasts.length,
          builder: (context, index) {
            final podcast = podcasts[index];
            return TvPosterCard(
              title: podcast.name,
              subtitle: podcast.authorName,
              thumbnailUrl: podcast.thumbnailUrl,

              onSelect: () => context.push('/podcast/${podcast.browseId}'),
            );
          },
        );
      },
    );
  }

  Widget _grid({
    required String memoryKey,
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
    double mainAxisExtent = TvMetrics.cardExtent,
  }) {
    return DpadRegion(
      memoryKey: memoryKey,
      debugLabel: memoryKey,
      horizontalEdge: DpadEdgeBehavior.stop,
      onEdge: (direction) {
        if (direction == TraversalDirection.left) {
          TvShellFocus.requestSidebar(context);
        }
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          TvMetrics.horizontalPadding,
          TvMetrics.verticalPadding,
          TvMetrics.horizontalPadding,
          TvMetrics.verticalPadding,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: TvMetrics.cardWidth + 24,
          mainAxisExtent: mainAxisExtent,
          crossAxisSpacing: TvMetrics.cardGap,
          mainAxisSpacing: TvMetrics.cardGap,
        ),
        itemCount: itemCount,
        itemBuilder: builder,
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool entry;
  final VoidCallback onSelect;

  const _SectionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
    this.entry = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusable(
        entry: entry,
        onSelect: onSelect,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
