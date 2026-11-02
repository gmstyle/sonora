import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../library/providers/library_provider.dart';
import '../../library/widgets/create_playlist_dialog.dart';
import '../../library/widgets/import_playlist_dialog.dart';
import '../../library/widgets/linked_playlist_actions.dart';
import '../../library/widgets/open_wrapped.dart';
import '../../library/widgets/playlist_detail_view.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

enum _TvLibrarySection {
  songs,
  albums,
  artists,
  playlists,
  podcasts,
  mixes,
  history,
  stats,
}

/// TV library with a section rail and a poster grid.
class TvLibraryScreen extends ConsumerStatefulWidget {
  const TvLibraryScreen({super.key});

  @override
  ConsumerState<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends ConsumerState<TvLibraryScreen> {
  _TvLibrarySection _section = _TvLibrarySection.songs;

  @override
  void initState() {
    super.initState();
    Future(
      () =>
          ref
              .read(libraryNotifierProvider.notifier)
              .refreshPlaylistThumbnailsIfNeeded(),
    );
  }

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
      _TvLibrarySection.mixes => l10n.mixes,
      _TvLibrarySection.history => l10n.history,
      _TvLibrarySection.stats => l10n.stats,
    };
  }

  IconData _icon(_TvLibrarySection section) {
    return switch (section) {
      _TvLibrarySection.songs => LucideIcons.heart,
      _TvLibrarySection.albums => LucideIcons.disc3,
      _TvLibrarySection.artists => LucideIcons.user,
      _TvLibrarySection.playlists => LucideIcons.listMusic,
      _TvLibrarySection.podcasts => LucideIcons.podcast,
      _TvLibrarySection.mixes => LucideIcons.sparkles,
      _TvLibrarySection.history => LucideIcons.history,
      _TvLibrarySection.stats => LucideIcons.barChart2,
    };
  }

  Widget _buildContent(AppLocalizations l10n) {
    return switch (_section) {
      _TvLibrarySection.songs => _songsGrid(l10n),
      _TvLibrarySection.albums => _albumsGrid(l10n),
      _TvLibrarySection.artists => _artistsGrid(l10n),
      _TvLibrarySection.playlists => _playlistsGrid(l10n),
      _TvLibrarySection.podcasts => _podcastsGrid(l10n),
      _TvLibrarySection.mixes => _mixesGrid(l10n),
      _TvLibrarySection.history => _historyGrid(l10n),
      _TvLibrarySection.stats => _statsContent(l10n),
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
              onLongSelect:
                  () => ContextMenuSheet.showForSong(
                    context,
                    videoId: song.videoId,
                    title: song.title,
                    artist: song.artist,
                    artistsJson: song.artistsJson,
                    thumbnailUrl: song.thumbnailUrl,
                    isVideo: song.isVideo,
                    isExplicit: song.isExplicit,
                    duration: song.duration,
                  ),
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
              onLongSelect:
                  () => ContextMenuSheet.showForAlbum(
                    context,
                    albumId: album.albumId,
                    name: album.name,
                    artist: album.artistName,
                    thumbnailUrl: album.thumbnailUrl,
                  ),
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
              onLongSelect:
                  () => ContextMenuSheet.showForArtist(
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
    // Two action tiles (create + import) precede local then liked playlists.
    const actionCount = 2;
    final total = actionCount + local.length + liked.length;

    return _grid(
      memoryKey: 'tv/library/playlists',
      itemCount: total,
      builder: (context, index) {
        if (index == 0) {
          return _TvActionCard(
            title: l10n.createPlaylist,
            icon: LucideIcons.plus,
            onSelect: () => _createPlaylist(context),
          );
        }
        if (index == 1) {
          return _TvActionCard(
            title: l10n.importPlaylist,
            icon: LucideIcons.import,
            onSelect: _importPlaylist,
          );
        }
        final playlistIndex = index - actionCount;
        if (playlistIndex < local.length) {
          final playlist = local[playlistIndex];
          final subtitle =
              playlist.isLinked
                  ? linkedSourceLabel(l10n, playlist)
                  : playlist.description;
          return TvPosterCard(
            title: playlist.name,
            subtitle: subtitle,
            onSelect: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => PlaylistDetailView(
                        playlist: playlist,
                        onUpdated: () => ref.invalidate(playlistsProvider),
                      ),
                ),
              );
            },
            onLongSelect:
                () => ContextMenuSheet.showForCustomPlaylist(
                  context,
                  playlist: playlist,
                  onUpdated: () => ref.invalidate(playlistsProvider),
                ),
          );
        }
        final playlist = liked[playlistIndex - local.length];
        return TvPosterCard(
          title: playlist.name,
          subtitle:
              playlist.videoCount != null
                  ? '${playlist.videoCount} videos'
                  : null,
          thumbnailUrl: playlist.thumbnailUrl,
          onSelect: () => context.push('/playlist/${playlist.playlistId}'),
          onLongSelect:
              () => ContextMenuSheet.showForPlaylist(
                context,
                playlistId: playlist.playlistId,
                name: playlist.name,
                thumbnailUrl: playlist.thumbnailUrl,
              ),
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => CreatePlaylistDialog(title: l10n.createPlaylist),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(libraryNotifierProvider.notifier).createPlaylist(result);
      ref.invalidate(playlistsProvider);
    }
  }

  Future<void> _importPlaylist() async {
    final result = await ImportPlaylistDialog.show(context);
    if (result != null && mounted) {
      ref.invalidate(playlistsProvider);
      final l10n = AppLocalizations.of(context)!;
      final message =
          result.skippedCount > 0
              ? l10n.playlistImportedPartial(
                result.importedCount,
                result.totalCount,
              )
              : l10n.playlistImported;
      ref.read(actionFeedbackProvider.notifier).report(message);
    }
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
              onLongSelect:
                  () => ContextMenuSheet.showForPodcast(
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

  Widget _mixesGrid(AppLocalizations l10n) {
    final items = <Widget>[
      _TvEntryCard(
        title: l10n.mixForThisMoment,
        subtitle: l10n.mixForThisMomentHint,
        icon: LucideIcons.sparkles,
        gradient: const LinearGradient(
          colors: [Color(0xFF5E35B1), Color(0xFFEC407A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onSelect: () => context.push('/moment-mix'),
      ),
      for (final type in SmartMixType.values)
        _TvEntryCard(
          title: _smartMixTitle(l10n, type),
          subtitle: _smartMixSubtitle(l10n, type),
          icon: _smartMixIcon(type),
          gradient: _smartMixGradient(type),
          onSelect: () => context.push('/smart-mix/${type.name}'),
        ),
    ];
    return _grid(
      memoryKey: 'tv/library/mixes',
      itemCount: items.length,
      builder: (context, index) => items[index],
    );
  }

  String _smartMixTitle(AppLocalizations l10n, SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => l10n.mostPlayed,
      SmartMixType.recentlyPlayed => l10n.recentlyPlayed,
      SmartMixType.forgottenFavorites => l10n.forgottenFavorites,
    };
  }

  String _smartMixSubtitle(AppLocalizations l10n, SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => l10n.mostPlayedDesc,
      SmartMixType.recentlyPlayed => l10n.recentlyPlayedDesc,
      SmartMixType.forgottenFavorites => l10n.forgottenFavoritesDesc,
    };
  }

  IconData _smartMixIcon(SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => LucideIcons.flame,
      SmartMixType.recentlyPlayed => LucideIcons.history,
      SmartMixType.forgottenFavorites => LucideIcons.heart,
    };
  }

  LinearGradient _smartMixGradient(SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFFFB300)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SmartMixType.recentlyPlayed => const LinearGradient(
        colors: [Color(0xFF3949AB), Color(0xFF8E24AA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SmartMixType.forgottenFavorites => const LinearGradient(
        colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };
  }

  Widget _historyGrid(AppLocalizations l10n) {
    final async = ref.watch(sortedHistoryProvider);
    return async.when(
      loading:
          () => const Center(
            child: ShimmerLoading(variant: ShimmerVariant.section),
          ),
      error:
          (_, _) => ErrorRetryWidget(
            message: l10n.failedToLoadHistory,
            onRetry: () => ref.invalidate(libraryHistoryProvider),
          ),
      data: (history) {
        if (history.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.history,
            title: l10n.noListeningHistory,
            body: l10n.noListeningHistoryHint,
          );
        }
        return _grid(
          memoryKey: 'tv/library/history',
          itemCount: history.length,
          builder: (context, index) {
            final h = history[index];
            final isEpisode = h.contentType == 'episode';
            return TvPosterCard(
              title: h.title,
              subtitle: isEpisode ? '${l10n.episode} · ${h.artist}' : h.artist,
              thumbnailUrl: h.thumbnailUrl,
              onSelect:
                  isEpisode
                      ? () => context.push('/episode/${h.videoId}')
                      : () => ref
                          .read(playerStateProvider.notifier)
                          .playVideoId(h.videoId, isVideo: h.isVideo),
              onLongSelect:
                  isEpisode
                      ? () => ContextMenuSheet.showForEpisode(
                        context,
                        videoId: h.videoId,
                        name: h.title,
                        podcastName: h.artist,
                        thumbnailUrl: h.thumbnailUrl,
                        podcastBrowseId: h.podcastBrowseId,
                      )
                      : () => ContextMenuSheet.showForSong(
                        context,
                        videoId: h.videoId,
                        title: h.title,
                        artist: h.artist,
                        thumbnailUrl: h.thumbnailUrl,
                        isVideo: h.isVideo,
                        isExplicit: h.isExplicit,
                        duration: h.duration,
                      ),
            );
          },
        );
      },
    );
  }

  Widget _statsContent(AppLocalizations l10n) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);
    if (stats.isLoading) {
      return const Center(
        child: ShimmerLoading(variant: ShimmerVariant.section),
      );
    }
    if (stats.topSongs.isEmpty &&
        stats.topEpisodes.isEmpty &&
        stats.topPodcasts.isEmpty) {
      return EmptyStateWidget(
        icon: LucideIcons.barChart2,
        title: l10n.insufficientData,
      );
    }

    final cards = <Widget>[
      if (stats.isWrappedAvailable)
        _TvActionCard(
          title: l10n.wrappedTitle,
          subtitle: l10n.wrappedIntro,
          icon: LucideIcons.sparkles,
          onSelect: () => openSonoraWrapped(context, ref),
        ),
      for (final song in stats.topSongs)
        TvPosterCard(
          title: song.title,
          subtitle: '${song.artist} · ${song.playCount} ${l10n.plays}',
          thumbnailUrl: song.thumbnailUrl,
          onSelect:
              () => ref
                  .read(playerStateProvider.notifier)
                  .playVideoId(song.videoId, isVideo: song.isVideo),
        ),
      for (final artist in stats.topArtists)
        TvPosterCard(
          title: artist.name,
          subtitle: '${artist.playCount} ${l10n.plays}',
          thumbnailUrl: artist.thumbnailUrl,
          circular: true,
          width: 160,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.horizontalPadding,
            TvMetrics.verticalPadding,
            TvMetrics.horizontalPadding,
            8,
          ),
          child: Text(
            '${stats.totalDurationMinutes} ${l10n.minutesLabel}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: _grid(
            memoryKey: 'tv/library/stats',
            itemCount: cards.length,
            builder: (context, index) => cards[index],
            topPadding: 8,
          ),
        ),
      ],
    );
  }

  Widget _grid({
    required String memoryKey,
    required int itemCount,
    required Widget Function(BuildContext, int) builder,
    double mainAxisExtent = TvMetrics.cardExtent,
    double topPadding = TvMetrics.verticalPadding,
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
        padding: EdgeInsets.fromLTRB(
          TvMetrics.horizontalPadding,
          topPadding,
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

class _TvActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onSelect;

  const _TvActionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onSelect != null;
    return SizedBox(
      width: TvMetrics.cardWidth,
      child: Opacity(
        opacity: enabled ? 1 : 0.85,
        child: TvFocusable(
          enabled: enabled,
          onSelect: onSelect,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: TvMetrics.cardArtSize,
                height: TvMetrics.cardArtSize,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 56, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvEntryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onSelect;

  const _TvEntryCard({
    required this.title,
    required this.icon,
    required this.gradient,
    this.subtitle,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onSelect != null;
    return SizedBox(
      width: TvMetrics.cardWidth,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: TvFocusable(
          enabled: enabled,
          onSelect: onSelect,
          debugLabel: 'entry:$title',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: TvMetrics.cardArtSize,
                height: TvMetrics.cardArtSize,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
