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

import '../../../providers/player_provider.dart';
import '../../../providers/palette_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/release_card.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_card.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/hover_carousel_arrows.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/video_badge.dart';
import '../../../shared/widgets/explicit_badge.dart';

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    return ListView(
      padding: EdgeInsets.only(top: topPadding + 8, bottom: 16),
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
              .playVideoId(
                item.videoId,
                isVideo: item.isVideo ?? false,
                isExplicit: item.isExplicit ?? false,
              ),
      onLongPress:
          () => ContextMenuSheet.showForSong(
            context,
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            thumbnailUrl: item.thumbnailUrl,
            duration: item.duration,
            isVideo: item.isVideo ?? false,
            playCount: item.playCount.toString(),
            isExplicit: item.isExplicit ?? false,
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
                if (item.isVideo ?? false)
                  const Positioned(
                    bottom: 6,
                    left: 6,
                    child: VideoBadge(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      borderRadius: 4,
                    ),
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
            Text.rich(
              TextSpan(
                children: [
                  if (item.isExplicit == true)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ExplicitBadge(),
                      ),
                    ),
                  TextSpan(
                    text: item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
        isVideo: item.type == 'VIDEO',
        isExplicit: item.isExplicit,
      );
    }
    if (item is VideoDetailed) {
      return SongCard(
        videoId: item.videoId,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        artist: item.artist.name,
        duration: item.duration,
        isVideo: true,
        artistId: item.artist.artistId,
        isExplicit: item.isExplicit,
      );
    }
    if (item is AlbumDetailed) {
      return AlbumCard(
        albumId: item.albumId,
        name: item.name,
        artist: item.artist.name,
        artistId: item.artist.artistId,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        year: item.year,
        heroTag: 'home_section_album_${item.albumId}',
      );
    }
    if (item is PlaylistDetailed) {
      return PlaylistCard(
        playlistId: item.playlistId,
        name: item.name,
        artist: item.artist.name,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        heroTag: 'home_section_playlist_${item.playlistId}',
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
        final height = cardWidth + 80;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.yourPlaylists,
          height: height,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final item = playlists[index];
            if (item is LocalPlaylistModel) {
              return PlaylistCard(
                localPlaylistId: item.id,
                localPlaylist: item,
                name: item.name,
                artist: item.description,
                cardWidth: cardWidth,
                heroTag: 'home_playlist_${item.id}',
              );
            } else if (item is LikedPlaylistModel) {
              return PlaylistCard(
                playlistId: item.playlistId,
                name: item.name,
                thumbnailUrl: item.thumbnailUrl,
                cardWidth: cardWidth,
                heroTag: 'home_playlist_${item.playlistId}',
              );
            }
            return const SizedBox.shrink();
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

class HomeYourMixes extends ConsumerWidget {
  final double cardWidth;

  const HomeYourMixes({super.key, this.cardWidth = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = cardWidth + 70;
    return _HomeCarouselSection(
      title: AppLocalizations.of(context)!.yourMixes,
      height: height,
      itemCount: 3,
      itemBuilder: (context, index) {
        final type = SmartMixType.values[index];
        return SmartMixCard(type: type, cardWidth: cardWidth);
      },
      onShowAll: () {
        ref
            .read(libraryActiveTabProvider.notifier)
            .update(5); // Mixes tab is index 5
        context.go('/library');
      },
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
              heroTag: 'home_your_artists_${artist.artistId}',
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
              artistId: album.artistId,
              thumbnailUrl: album.thumbnailUrl,
              year: album.year,
              cardWidth: cardWidth,
              heroTag: 'home_liked_album_${album.albumId}',
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
            return ReleaseCard(
              albumId: album.albumId,
              name: album.name,
              artist: album.artist.name,
              artistId: album.artist.artistId,
              thumbnailUrl:
                  album.thumbnails.isNotEmpty
                      ? album.thumbnails.last.url
                      : null,
              year: album.year,
              type: ReleaseType.album,
              cardWidth: cardWidth,
              badgeText: 'NEW',
              showArtist: true,
              heroTag: 'new_release_${album.albumId}',
            );
          },
        );
      },
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
              isVideo: song.type == 'VIDEO',
              isExplicit: song.isExplicit,
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
              heroTag: 'home_similar_artists_${artist.artistId}',
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

    if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      backgroundWidget = Align(
        alignment: Alignment.topCenter,
        child: Container(
          key: const ValueKey('image_bg'),
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          foregroundDecoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface.withValues(
                  alpha: isThemeDark ? 0.15 : 0.08,
                ),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
                Theme.of(context).colorScheme.surface,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: CachedNetworkImage(
              imageUrl: backgroundUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    } else if (currentSong != null) {
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
