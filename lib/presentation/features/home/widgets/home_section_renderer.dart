import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';

import '../../../providers/player_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_card.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/hover_carousel_arrows.dart';
import '../../../shared/widgets/scale_button.dart';

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

  const HomeContinueListening(this.historyAsync, {super.key});

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
              height: 120,
              child: HoverCarouselArrows(
                controller: _scrollController,
                scrollAmount: 300.0,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return _ContinueListeningItem(item: item);
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

  const _ContinueListeningItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap:
          () =>
              ref.read(playerStateProvider.notifier).playVideoId(item.videoId),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ThumbnailWidget(
                  imageUrl: item.thumbnailUrl,
                  size: 100,
                  shape: ThumbnailShape.rounded,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
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
            const SizedBox(height: 4),
            Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
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
          height: 220,
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

    return ScaleButton(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Hero(
              tag: 'hero_art_$title',
              child: ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: 188,
                shape: ThumbnailShape.rounded,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
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
                          size: 20,
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
