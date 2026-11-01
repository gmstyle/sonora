import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/providers/home_provider.dart';
import '../../library/widgets/playlist_detail_view.dart';
import '../tv_metrics.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_shelf.dart';

/// 10-foot Home: vertical shelves of D-pad focusable posters.
class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sectionsAsync = ref.watch(homeBaseSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);
    final playlistsAsync = ref.watch(homeRandomPlaylistsProvider);
    final artistsAsync = ref.watch(homeRandomArtistsProvider);
    final albumsAsync = ref.watch(homeRandomAlbumsProvider);

    return Scaffold(
      body: sectionsAsync.when(
        loading:
            () => const Center(
              child: ShimmerLoading(variant: ShimmerVariant.section),
            ),
        error:
            (_, _) => ErrorRetryWidget(
              message: l10n.failedToLoadHomeFeed,
              onRetry: () => ref.invalidate(homeBaseResultProvider),
            ),
        data: (sections) {
          return ListView(
            padding: const EdgeInsets.only(
              top: TvMetrics.verticalPadding,
              bottom: TvMetrics.verticalPadding,
            ),
            children: [
              historyAsync.maybeWhen(
                data: (history) {
                  if (history.isEmpty) return const SizedBox.shrink();
                  final items = history.take(12).toList();
                  return TvShelf(
                    title: l10n.recentlyPlayed,
                    memoryKey: 'tv/home/history',
                    children: [
                      for (final item in items)
                        _historyCard(context, ref, item),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              playlistsAsync.maybeWhen(
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return TvShelf(
                    title: l10n.yourMusicZone,
                    memoryKey: 'tv/home/playlists',
                    children: [
                      for (final item in items.take(12))
                        _playlistLikeCard(context, item),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              artistsAsync.maybeWhen(
                data: (artists) {
                  if (artists.isEmpty) return const SizedBox.shrink();
                  return TvShelf(
                    title: l10n.artists,
                    memoryKey: 'tv/home/artists',
                    height: 260,
                    children: [
                      for (final artist in artists.take(12))
                        TvPosterCard(
                          title: artist.name,
                          thumbnailUrl: artist.thumbnailUrl,
                          circular: true,
                          width: 160,
                          onSelect:
                              () => context.push('/artist/${artist.artistId}'),
                        ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              albumsAsync.maybeWhen(
                data: (albums) {
                  if (albums.isEmpty) return const SizedBox.shrink();
                  return TvShelf(
                    title: l10n.albums,
                    memoryKey: 'tv/home/albums',
                    children: [
                      for (final album in albums.take(12))
                        TvPosterCard(
                          title: album.name,
                          subtitle: album.artistName,
                          thumbnailUrl: album.thumbnailUrl,
                          onSelect:
                              () => context.push('/album/${album.albumId}'),
                        ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              for (var s = 0; s < sections.length; s++)
                _sectionShelf(context, ref, sections[s], s),
            ],
          );
        },
      ),
    );
  }

  Widget _historyCard(BuildContext context, WidgetRef ref, HistoryModel item) {
    return TvPosterCard(
      title: item.title,
      subtitle: item.artist,
      thumbnailUrl: item.thumbnailUrl,
      onSelect:
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(item.videoId, isVideo: item.isVideo),
    );
  }

  Widget _playlistLikeCard(BuildContext context, dynamic item) {
    if (item is LikedPlaylistModel) {
      return TvPosterCard(
        title: item.name,
        thumbnailUrl: item.thumbnailUrl,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    if (item is LocalPlaylistModel) {
      return TvPosterCard(
        title: item.name,
        onSelect: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => PlaylistDetailView(playlist: item, onUpdated: () {}),
            ),
          );
        },
      );
    }
    if (item is PlaylistDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _sectionShelf(
    BuildContext context,
    WidgetRef ref,
    HomeSection section,
    int index,
  ) {
    final cards = <Widget>[];
    for (final item in section.contents.take(12)) {
      final card = _catalogCard(context, ref, item);
      if (card != null) cards.add(card);
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return TvShelf(
      title: section.title,
      memoryKey: 'tv/home/section-$index',
      children: cards,
    );
  }

  Widget? _catalogCard(BuildContext context, WidgetRef ref, dynamic item) {
    if (item is SongDetailed || item is VideoDetailed) {
      final videoId =
          item is SongDetailed ? item.videoId : (item as VideoDetailed).videoId;
      final name =
          item is SongDetailed ? item.name : (item as VideoDetailed).name;
      final artists =
          item is SongDetailed ? item.artists : (item as VideoDetailed).artists;
      final thumbs =
          item is SongDetailed
              ? item.thumbnails
              : (item as VideoDetailed).thumbnails;
      final isVideo =
          item is VideoDetailed ||
          (item is SongDetailed && item.type == 'VIDEO');
      final isPlayable =
          item is SongDetailed
              ? item.isPlayable
              : (item as VideoDetailed).isPlayable;
      final isExplicit =
          item is SongDetailed
              ? item.isExplicit
              : (item as VideoDetailed).isExplicit;
      return TvPosterCard(
        title: name,
        subtitle: displayArtists(artists),
        thumbnailUrl: thumbs.isNotEmpty ? thumbs.last.url : null,
        onSelect:
            isPlayable
                ? () => ref
                    .read(playerStateProvider.notifier)
                    .playVideoId(
                      videoId,
                      isVideo: isVideo,
                      isExplicit: isExplicit,
                    )
                : null,
      );
    }
    if (item is AlbumDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onSelect: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    if (item is ArtistDetailed) {
      return TvPosterCard(
        title: item.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        circular: true,
        width: 160,
        onSelect: () => context.push('/artist/${item.artistId}'),
      );
    }
    if (item is PodcastDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: item.author,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onSelect: () => context.push('/podcast/${item.browseId}'),
      );
    }
    return null;
  }
}
