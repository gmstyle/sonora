import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';

import '../../../providers/player_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_card.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/hover_carousel_arrows.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../shared/widgets/context_menu_sheet.dart';

class HomeShimmer extends StatelessWidget {
  final int tileCount;

  const HomeShimmer({super.key, this.tileCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerLoading(variant: ShimmerVariant.carousel),
        const SizedBox(height: 24),
        for (var i = 0; i < tileCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ShimmerLoading(variant: ShimmerVariant.tile),
          ),
      ],
    );
  }
}

class HomeContinueListening extends StatefulWidget {
  final AsyncValue historyAsync;
  final double cardWidth;

  const HomeContinueListening(
    this.historyAsync, {
    super.key,
    this.cardWidth = 140,
  });

  @override
  State<HomeContinueListening> createState() => _HomeContinueListeningState();
}

class _HomeContinueListeningState extends State<HomeContinueListening> {
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
              child: Text(
                AppLocalizations.of(context)!.continueListening,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
          () =>
              ref.read(playerStateProvider.notifier).playVideoId(item.videoId),
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

  const HomeSectionRow({
    super.key,
    required this.section,
    this.isFirst = false,
    this.cardWidth = 150,
    this.heroViewportFraction = 0.85,
    this.sectionPadding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.contents.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kCompactBreakpoint;
    final double carouselHeight = isFirst ? (isMobile ? 180.0 : 220.0) : 220.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: sectionPadding,
          child: Text(
            section.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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

  const _HorizontalCardRow({required this.items, this.cardWidth = 150});

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

class HomeYourPlaylists extends StatelessWidget {
  final AsyncValue<List<dynamic>> playlistsAsync;
  final double cardWidth;

  const HomeYourPlaylists(
    this.playlistsAsync, {
    super.key,
    this.cardWidth = 140,
  });

  @override
  Widget build(BuildContext context) {
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
        );
      },
    );
  }
}

class _HomePlaylistTile extends StatelessWidget {
  final dynamic item;
  final double cardWidth;

  const _HomePlaylistTile({required this.item, this.cardWidth = 140});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    String name;
    String? thumbnailUrl;
    String route;

    if (item is LocalPlaylistModel) {
      name = item.name;
      thumbnailUrl = null;
      route = '/playlist/local/${item.id}';
    } else if (item is LikedPlaylistModel) {
      name = item.name;
      thumbnailUrl = item.thumbnailUrl;
      route = '/playlist/${item.playlistId}';
    } else {
      return const SizedBox.shrink();
    }

    return ScaleButton(
      onTap: () => context.push(route),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

class HomeYourArtists extends StatelessWidget {
  final AsyncValue<List<FollowedArtistModel>> artistsAsync;
  final double cardWidth;

  const HomeYourArtists(this.artistsAsync, {super.key, this.cardWidth = 120});

  @override
  Widget build(BuildContext context) {
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
        );
      },
    );
  }
}

class HomeLikedAlbums extends StatelessWidget {
  final AsyncValue<List<LikedAlbumModel>> albumsAsync;
  final double cardWidth;

  const HomeLikedAlbums(this.albumsAsync, {super.key, this.cardWidth = 140});

  @override
  Widget build(BuildContext context) {
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

  const _HomeCarouselSection({
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
