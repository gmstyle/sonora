import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/home_provider.dart';
import '../../library/providers/library_provider.dart';
import '../../library/widgets/playlist_detail_view.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/palette_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/playlist_cover_collage.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_card.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/hover_carousel_arrows.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../shared/widgets/context_menu_sheet.dart';

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: const [
        ShimmerLoading(variant: ShimmerVariant.chipsBar),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
        ShimmerLoading(variant: ShimmerVariant.section),
      ],
    );
  }
}

class HomeContinueListening extends ConsumerStatefulWidget {
  final AsyncValue historyAsync;
  final double cardWidth;

  const HomeContinueListening(
    this.historyAsync, {
    super.key,
    this.cardWidth = 140,
  });

  @override
  ConsumerState<HomeContinueListening> createState() =>
      _HomeContinueListeningState();
}

class _HomeContinueListeningState extends ConsumerState<HomeContinueListening> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final showAllLabel = isIt ? 'Vedi tutto' : 'Show all';

    return widget.historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.continueListening,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(libraryActiveTabProvider.notifier)
                          .update(4); // History is index 4
                      context.go('/library');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showAllLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: widget.cardWidth + 48,
              child: HoverCarouselArrows(
                controller: _scrollController,
                scrollAmount: widget.cardWidth * 2,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return _ContinueListeningItem(
                      item: item,
                      cardWidth: widget.cardWidth,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _ContinueListeningItem extends ConsumerWidget {
  final dynamic item;
  final double cardWidth;

  const _ContinueListeningItem({required this.item, this.cardWidth = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaleButton(
      onTap:
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(item.videoId, isVideo: item.isVideo ?? false),
      onLongPress:
          () => ContextMenuSheet.showForSong(
            context,
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            thumbnailUrl: item.thumbnailUrl,
            playCount: item.playCount.toString(),
          ),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: item.thumbnailUrl,
                  size: cardWidth,
                  shape: ThumbnailShape.rounded,
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.play,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeSectionRow extends ConsumerWidget {
  final HomeSection section;
  final bool isFirst;
  final double cardWidth;
  final double heroViewportFraction;
  final EdgeInsets sectionPadding;
  final VoidCallback? onShowAll;

  const HomeSectionRow({
    super.key,
    required this.section,
    this.isFirst = false,
    this.cardWidth = 150,
    this.heroViewportFraction = 0.85,
    this.sectionPadding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
    this.onShowAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.contents.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kCompactBreakpoint;
    final double carouselHeight =
        isFirst ? (isMobile ? 180.0 : 220.0) : (cardWidth + 80.0);

    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final showAllLabel = isIt ? 'Vedi tutto' : 'Show all';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: sectionPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onShowAll != null)
                TextButton(
                  onPressed: onShowAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        showAllLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: carouselHeight,
          child:
              isFirst
                  ? _HeroCarousel(
                    items: section.contents,
                    viewportFraction: heroViewportFraction,
                  )
                  : _HorizontalCardRow(
                    items: section.contents,
                    cardWidth: cardWidth,
                    shelfId: section.shelfId,
                  ),
        ),
      ],
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  final List<dynamic> items;
  final double viewportFraction;

  const _HeroCarousel({required this.items, this.viewportFraction = 0.85});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: widget.viewportFraction);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HoverCarouselArrows(
      controller: _pageController,
      scrollAmount: 600.0,
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 8,
              right: index == widget.items.length - 1 ? 16 : 8,
            ),
            child: _buildItem(context, item),
          );
        },
      ),
    );
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    if (item is AlbumDetailed) {
      return _HeroCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        onTap: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return _HeroCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        onTap: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _HeroCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _HeroCard({
    required this.thumbnailUrl,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600; // kCompactBreakpoint is 600

    final cardHeight = isMobile ? 180.0 : 220.0;
    final thumbnailSize = isMobile ? 140.0 : 188.0;
    final gap = isMobile ? 14.0 : 20.0;
    final playBtnSize = isMobile ? 38.0 : 44.0;
    final playIconSize = isMobile ? 18.0 : 20.0;

    return ScaleButton(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Row(
          children: [
            Hero(
              tag: 'hero_art_$title',
              child: ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: thumbnailSize,
                shape: ThumbnailShape.rounded,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isMobile ? 4.0 : 12.0),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: isMobile ? 4.0 : 6.0),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (isMobile
                              ? textTheme.bodySmall
                              : textTheme.bodyMedium)
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: playBtnSize,
                        height: playBtnSize,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.play,
                          color: colorScheme.onPrimary,
                          size: playIconSize,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalCardRow extends StatefulWidget {
  final List<dynamic> items;
  final double cardWidth;
  final String? shelfId;

  const _HorizontalCardRow({
    required this.items,
    this.cardWidth = 150,
    this.shelfId,
  });

  @override
  State<_HorizontalCardRow> createState() => _HorizontalCardRowState();
}

class _HorizontalCardRowState extends State<_HorizontalCardRow> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HoverCarouselArrows(
      controller: _scrollController,
      scrollAmount: widget.cardWidth * 3, // Scroll by 3 cards at a time
      child: ListView.separated(
        key: widget.shelfId != null ? PageStorageKey(widget.shelfId) : null,
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const PageScrollPhysics(),
        itemCount: widget.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _buildItem(context, item);
        },
      ),
    );
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    if (item is SongDetailed) {
      return SongCard(
        videoId: item.videoId,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        artist: item.artist.name,
        duration: item.duration,
        playCount: item.playCount,
        artistId: item.artist.artistId,
        albumId: item.album?.albumId,
      );
    }
    if (item is AlbumDetailed) {
      return AlbumCard(
        albumId: item.albumId,
        name: item.name,
        artist: item.artist.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        year: item.year,
      );
    }
    if (item is PlaylistDetailed) {
      return PlaylistCard(
        playlistId: item.playlistId,
        name: item.name,
        artist: item.artist.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
      );
    }
    return const SizedBox.shrink();
  }
}

class HomeYourPlaylists extends ConsumerWidget {
  final AsyncValue<List<dynamic>> playlistsAsync;
  final double cardWidth;

  const HomeYourPlaylists(
    this.playlistsAsync, {
    super.key,
    this.cardWidth = 140,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return playlistsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + 60;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.yourPlaylists,
          height: height,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final item = playlists[index];
            return _HomePlaylistTile(item: item, cardWidth: cardWidth);
          },
          onShowAll: () {
            ref
                .read(libraryActiveTabProvider.notifier)
                .update(2); // Playlists is index 2
            context.go('/library');
          },
        );
      },
    );
  }
}

class _LocalPlaylistCover extends ConsumerWidget {
  final int playlistId;
  final double size;

  const _LocalPlaylistCover({required this.playlistId, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(playlistEntriesProvider(playlistId));
    final likedSongs = ref.watch(likedSongsProvider).asData?.value ?? [];

    final urls = switch (entriesAsync) {
      AsyncData(:final value) =>
        value
            .map((e) {
              final liked = likedSongs.cast<LikedSongModel?>().firstWhere(
                (l) => l?.videoId == e.videoId,
                orElse: () => null,
              );
              return liked?.thumbnailUrl ?? e.thumbnailUrl;
            })
            .where((u) => u != null && u.isNotEmpty)
            .cast<String>()
            .take(3)
            .toList(),
      _ => <String>[],
    };

    return SizedBox(
      width: size,
      height: size,
      child: PlaylistCoverCollage(thumbnailUrls: urls, borderRadius: 8),
    );
  }
}

class _HomePlaylistTile extends ConsumerWidget {
  final dynamic item;
  final double cardWidth;

  const _HomePlaylistTile({required this.item, this.cardWidth = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    String name;
    String? thumbnailUrl;

    if (item is LocalPlaylistModel) {
      name = item.name;
      thumbnailUrl = null;
    } else if (item is LikedPlaylistModel) {
      name = item.name;
      thumbnailUrl = item.thumbnailUrl;
    } else {
      return const SizedBox.shrink();
    }

    return ScaleButton(
      onTap: () {
        if (item is LocalPlaylistModel) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => PlaylistDetailView(
                    playlist: item,
                    onUpdated: () {
                      ref.invalidate(playlistsProvider);
                    },
                  ),
            ),
          );
        } else if (item is LikedPlaylistModel) {
          context.push('/playlist/${item.playlistId}');
        }
      },
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item is LocalPlaylistModel)
              _LocalPlaylistCover(playlistId: item.id, size: cardWidth)
            else
              ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: cardWidth,
                shape: ThumbnailShape.rounded,
              ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeYourArtists extends ConsumerWidget {
  final AsyncValue<List<FollowedArtistModel>> artistsAsync;
  final double cardWidth;

  const HomeYourArtists(this.artistsAsync, {super.key, this.cardWidth = 120});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return artistsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + 60;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.yourArtists,
          height: height,
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ArtistCard(
              artistId: artist.artistId,
              name: artist.name,
              thumbnailUrl: artist.thumbnailUrl,
              cardWidth: cardWidth,
            );
          },
          onShowAll: () {
            ref
                .read(libraryActiveTabProvider.notifier)
                .update(1); // Artists is index 1
            context.go('/library');
          },
        );
      },
    );
  }
}

class HomeLikedAlbums extends ConsumerWidget {
  final AsyncValue<List<LikedAlbumModel>> albumsAsync;
  final double cardWidth;

  const HomeLikedAlbums(this.albumsAsync, {super.key, this.cardWidth = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return albumsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + 80;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.likedAlbumsHome,
          height: height,
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumCard(
              albumId: album.albumId,
              name: album.name,
              artist: album.artistName,
              thumbnailUrl: album.thumbnailUrl,
              year: album.year,
              cardWidth: cardWidth,
            );
          },
          onShowAll: () {
            ref
                .read(libraryActiveTabProvider.notifier)
                .update(3); // Albums is index 3
            context.go('/library');
          },
        );
      },
    );
  }
}

class HomeNewReleases extends StatelessWidget {
  final AsyncValue<List<AlbumDetailed>> albumsAsync;
  final double cardWidth;

  const HomeNewReleases(this.albumsAsync, {super.key, this.cardWidth = 140});

  @override
  Widget build(BuildContext context) {
    return albumsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + 80;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.newReleases,
          height: height,
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _NewReleaseTile(
              albumId: album.albumId,
              name: album.name,
              artist: album.artist.name,
              thumbnailUrl:
                  album.thumbnails.isNotEmpty
                      ? album.thumbnails.last.url
                      : null,
              year: album.year,
              cardWidth: cardWidth,
            );
          },
        );
      },
    );
  }
}

class _NewReleaseTile extends StatelessWidget {
  final String albumId;
  final String name;
  final String artist;
  final String? thumbnailUrl;
  final int? year;
  final double cardWidth;

  const _NewReleaseTile({
    required this.albumId,
    required this.name,
    required this.artist,
    this.thumbnailUrl,
    this.year,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ScaleButton(
      onTap: () => context.push('/album/$albumId'),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: cardWidth,
                  shape: ThumbnailShape.rounded,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NEW',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              [artist, if (year != null) '$year'].join(' · '),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeDiscover extends StatelessWidget {
  final AsyncValue<List<UpNextsDetails>> discoverAsync;
  final double cardWidth;

  const HomeDiscover(this.discoverAsync, {super.key, this.cardWidth = 140});

  @override
  Widget build(BuildContext context) {
    return discoverAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + 80;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.discover,
          height: height,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final song = suggestions[index];
            return SongCard(
              videoId: song.videoId,
              thumbnailUrl:
                  song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
              title: song.title,
              artist: song.artists.name,
              duration: song.duration,
              artistId: song.artists.artistId,
              albumId: song.album?.albumId,
              cardWidth: cardWidth,
            );
          },
        );
      },
    );
  }
}

class HomeSimilarArtists extends StatelessWidget {
  final AsyncValue<List<ArtistDetailed>> artistsAsync;
  final double cardWidth;

  const HomeSimilarArtists(
    this.artistsAsync, {
    super.key,
    this.cardWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    return artistsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + 60;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.similarArtistsHome,
          height: height,
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ArtistCard(
              artistId: artist.artistId,
              name: artist.name,
              thumbnailUrl:
                  artist.thumbnails.isNotEmpty
                      ? artist.thumbnails.last.url
                      : null,
              monthlyListeners: artist.monthlyListeners,
              cardWidth: cardWidth,
            );
          },
        );
      },
    );
  }
}

class _HomeCarouselSection extends StatefulWidget {
  final String title;
  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback? onShowAll;

  const _HomeCarouselSection({
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.onShowAll,
  });

  @override
  State<_HomeCarouselSection> createState() => _HomeCarouselSectionState();
}

class _HomeCarouselSectionState extends State<_HomeCarouselSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final showAllLabel = isIt ? 'Vedi tutto' : 'Show all';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.onShowAll != null)
                TextButton(
                  onPressed: widget.onShowAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        showAllLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: widget.height,
          child: HoverCarouselArrows(
            controller: _scrollController,
            scrollAmount: 300.0,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class HomeChipsBar extends ConsumerWidget {
  const HomeChipsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(homeResultProvider);

    return resultAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final filteredChips =
            data.chips.where((chip) {
              final titleLower = chip.title.toLowerCase();
              return titleLower != 'podcasts' && titleLower != 'podcast';
            }).toList();

        if (filteredChips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredChips.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isTuttoSelected =
                    ref.watch(homeSelectedChipParamsProvider) == null;
                return ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.all),
                  selected: isTuttoSelected,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(homeSelectedChipParamsProvider.notifier)
                          .update(null);
                    }
                  },
                );
              }

              final chip = filteredChips[index - 1];
              final isSelected =
                  ref.watch(homeSelectedChipParamsProvider) == chip.params;

              return ChoiceChip(
                label: Text(chip.title),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ref
                        .read(homeSelectedChipParamsProvider.notifier)
                        .update(chip.params);
                  } else {
                    ref
                        .read(homeSelectedChipParamsProvider.notifier)
                        .update(null);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class AmbientBackground extends ConsumerWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;
    final paletteMap = ref.watch(paletteNotifierProvider);
    final homeResultAsync = ref.watch(homeResultProvider);

    final backgroundUrl = homeResultAsync.when(
      data: (data) => data.backgroundUrl,
      loading: () => null,
      error: (_, _) => null,
    );

    Color dominantColor = Theme.of(context).colorScheme.surface;

    if (currentSong != null) {
      final videoId = currentSong.id;
      final artUrl = currentSong.artUri?.toString();
      if (artUrl != null && artUrl.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(paletteNotifierProvider.notifier)
              .extractPalette(videoId, artUrl);
        });

        final paletteData = paletteMap[videoId];
        if (paletteData != null) {
          dominantColor = paletteData.dominantColor;
        }
      }
    }

    final isThemeDark = Theme.of(context).brightness == Brightness.dark;

    Widget backgroundWidget;

    if (currentSong != null) {
      final ambientColor = dominantColor.withValues(
        alpha: isThemeDark ? 0.15 : 0.08,
      );
      backgroundWidget = AnimatedContainer(
        key: const ValueKey('gradient_bg'),
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ambientColor, Theme.of(context).colorScheme.surface],
            stops: const [0.0, 0.45],
          ),
        ),
      );
    } else if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      backgroundWidget = Container(
        key: const ValueKey('image_bg'),
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.45,
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: isThemeDark ? 0.5 : 0.3),
              Theme.of(context).colorScheme.surface,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: CachedNetworkImage(
            imageUrl: backgroundUrl,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    } else {
      backgroundWidget = Container(
        key: const ValueKey('empty_bg'),
        color: Theme.of(context).colorScheme.surface,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: backgroundWidget,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
