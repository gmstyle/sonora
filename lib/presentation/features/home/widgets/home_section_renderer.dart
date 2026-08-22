import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/home_provider.dart';
import '../../library/providers/library_provider.dart';

import '../../../providers/player_provider.dart';
import '../../../providers/palette_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/release_card.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_card.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/hover_carousel_arrows.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shelf_card_layout.dart';
import '../layouts/home_layout_metrics.dart';
import 'home_zone_header.dart';

/// True when async list data is loaded and non-empty (loading/error → false).
bool asyncListHasContent<T>(AsyncValue<List<T>> async) {
  return async.when(
    data: (list) => list.isNotEmpty,
    loading: () => false,
    error: (_, _) => false,
  );
}

/// True when a history/recent-items async value has displayable rows.
bool asyncHistoryHasContent(AsyncValue async) {
  return async.when(
    data: (history) => history.isNotEmpty,
    loading: () => false,
    error: (_, _) => false,
  );
}

class HomeShimmer extends StatelessWidget {
  final HomeLayoutMetrics metrics;

  const HomeShimmer({super.key, required this.metrics});

  ShimmerLoading _homeShimmer(ShimmerVariant variant) {
    return ShimmerLoading(
      variant: variant,
      cardWidth: metrics.cardWidth,
      horizontalPadding: metrics.horizontalPadding,
      heroHeight: metrics.heroHeight,
      sideBySideQuickRow: metrics.useSideBySideQuickRow,
      zoneHeaderTop: metrics.zoneHeaderTop,
      zoneHeaderBottom: metrics.zoneHeaderBottom,
      zoneGap: metrics.zoneGap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    return ListView(
      padding: EdgeInsets.only(top: topPadding + 8, bottom: 16),
      children: [
        _homeShimmer(ShimmerVariant.homeQuickRow),
        _homeShimmer(ShimmerVariant.zoneHeader),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.zoneHeader),
        _homeShimmer(ShimmerVariant.hero),
        _homeShimmer(ShimmerVariant.exploreChips),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.zoneHeader),
        _homeShimmer(ShimmerVariant.chipsBar),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.section),
        _homeShimmer(ShimmerVariant.section),
      ],
    );
  }
}

class HomeEditorialLoading extends StatelessWidget {
  final HomeLayoutMetrics metrics;

  const HomeEditorialLoading({super.key, required this.metrics});

  ShimmerLoading _sectionShimmer() {
    return ShimmerLoading(
      variant: ShimmerVariant.section,
      cardWidth: metrics.cardWidth,
      horizontalPadding: metrics.horizontalPadding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_sectionShimmer(), _sectionShimmer(), _sectionShimmer()],
    );
  }
}

class HomeEditorialZone extends ConsumerWidget {
  final HomeLayoutMetrics metrics;

  const HomeEditorialZone({super.key, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final baseResultAsync = ref.watch(homeBaseResultProvider);
    final editorialAsync = ref.watch(homeEditorialSectionsProvider);
    final activeChipParams = ref.watch(homeSelectedChipParamsProvider);

    final hasChips = baseResultAsync.when(
      data: (data) => data.chips.isNotEmpty,
      loading: () => false,
      error: (_, _) => false,
    );

    final editorialSections = editorialAsync.when(
      data: (sections) => sections.where((s) => s.contents.isNotEmpty).toList(),
      loading: () => const <HomeSection>[],
      error: (_, _) => const <HomeSection>[],
    );
    final hasShelves = editorialSections.isNotEmpty;
    final editorialLoading =
        editorialAsync.isLoading && !editorialAsync.hasValue;
    final editorialError = editorialAsync.hasError && !editorialAsync.hasValue;

    if (!hasChips && !hasShelves) {
      if (editorialLoading) return const SizedBox.shrink();
      if (editorialError) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.horizontalPadding,
            vertical: 16,
          ),
          child: ErrorRetryWidget(
            message: l10n.failedToLoadHomeFeed,
            onRetry: () => ref.invalidate(homeEditorialSectionsProvider),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeZoneHeader(title: l10n.editorialZone, metrics: metrics),
        if (hasChips)
          HomeChipsBar(horizontalPadding: metrics.horizontalPadding),
        if (editorialAsync.isReloading)
          LinearProgressIndicator(
            minHeight: 2,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            backgroundColor: Colors.transparent,
          ),
        editorialAsync.when(
          skipLoadingOnReload: true,
          loading:
              () =>
                  hasChips
                      ? HomeEditorialLoading(metrics: metrics)
                      : const SizedBox.shrink(),
          error:
              (_, _) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.horizontalPadding,
                  vertical: 16,
                ),
                child: ErrorRetryWidget(
                  message: l10n.failedToLoadHomeFeed,
                  onRetry: () => ref.invalidate(homeEditorialSectionsProvider),
                ),
              ),
          data: (_) {
            if (!hasShelves) return const SizedBox.shrink();
            return Column(
              children: [
                for (var i = 0; i < editorialSections.length; i++)
                  HomeSectionRow(
                    section: editorialSections[i],
                    isFirst:
                        activeChipParams != null &&
                        i == 0 &&
                        _sectionUsesHeroCarousel(editorialSections[i]),
                    metrics: metrics,
                    onShowAll: _browseCallback(context, editorialSections[i]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  VoidCallback? _browseCallback(BuildContext context, HomeSection section) {
    if (section.browseId == null) return null;
    return () {
      final titleEncoded = Uri.encodeComponent(section.title);
      final paramsEncoded =
          section.browseParams != null ? '&params=${section.browseParams}' : '';
      context.push(
        '/browse-section/${section.browseId}?title=$titleEncoded$paramsEncoded',
      );
    };
  }
}

class HomeContinueListening extends ConsumerWidget {
  final AsyncValue historyAsync;
  final double thumbnailSize;
  final double horizontalPadding;
  final bool showHeader;
  final int maxItems;

  const HomeContinueListening(
    this.historyAsync, {
    super.key,
    this.thumbnailSize = 48,
    this.horizontalPadding = 16,
    this.showHeader = true,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final showAllLabel = isIt ? 'Vedi tutto' : 'Show all';

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        final items = history.take(maxItems).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.continueListening,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(libraryActiveTabProvider.notifier).update(4);
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  for (final item in items)
                    SongTile(
                      videoId: item.videoId,
                      title: item.title,
                      artist: item.artist,
                      thumbnailUrl: item.thumbnailUrl,
                      duration: item.duration,
                      isVideo: item.isVideo ?? false,
                      isExplicit: item.isExplicit ?? false,
                      playCount: item.playCount?.toString(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

bool _sectionUsesHeroCarousel(HomeSection section) {
  if (section.contents.isEmpty) return false;
  final first = section.contents.first;
  return first is AlbumDetailed || first is PlaylistDetailed;
}

double _sectionCarouselHeight(
  HomeSection section, {
  required bool isFirst,
  required HomeLayoutMetrics metrics,
}) {
  if (isFirst) return metrics.heroHeight;
  if (section.contents.isNotEmpty &&
      section.contents.first is EpisodeDetailed) {
    return HomeLayoutMetrics.episodeShelfHeight;
  }
  return metrics.carouselShelfHeight;
}

class HomeSectionRow extends ConsumerWidget {
  final HomeSection section;
  final bool isFirst;
  final HomeLayoutMetrics metrics;
  final VoidCallback? onShowAll;

  const HomeSectionRow({
    super.key,
    required this.section,
    this.isFirst = false,
    required this.metrics,
    this.onShowAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.contents.isEmpty) return const SizedBox.shrink();

    final carouselHeight = _sectionCarouselHeight(
      section,
      isFirst: isFirst,
      metrics: metrics,
    );

    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final showAllLabel = isIt ? 'Vedi tutto' : 'Show all';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: metrics.sectionPadding,
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
                    viewportFraction: metrics.heroViewportFraction,
                    heroHeight: carouselHeight,
                  )
                  : _HorizontalCardRow(
                    items: section.contents,
                    metrics: metrics,
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
  final double heroHeight;

  const _HeroCarousel({
    required this.items,
    this.viewportFraction = 0.85,
    this.heroHeight = 160,
  });

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
        heroHeight: widget.heroHeight,
        onTap: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return _HeroCard(
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        title: item.name,
        subtitle: item.artist.name,
        heroHeight: widget.heroHeight,
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
  final double heroHeight;
  final VoidCallback onTap;

  const _HeroCard({
    required this.thumbnailUrl,
    required this.title,
    this.subtitle,
    this.heroHeight = 160,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = heroHeight <= 180;

    final thumbnailSize = isCompact ? heroHeight - 24 : heroHeight - 32;
    final gap = isCompact ? 12.0 : 20.0;
    final playBtnSize = isCompact ? 36.0 : 44.0;
    final playIconSize = isCompact ? 16.0 : 20.0;

    return ScaleButton(
      onTap: onTap,
      child: Container(
        height: heroHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
              ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: heroHeight * 2,
                shape: ThumbnailShape.rounded,
              )
            else
              ColoredBox(color: colorScheme.surfaceContainerHigh),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colorScheme.surface.withValues(alpha: 0.4),
                    colorScheme.surface.withValues(alpha: 0.92),
                  ],
                  stops: const [0.35, 0.65, 1.0],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              child: Row(
                children: [
                  Hero(
                    tag: 'hero_art_$title',
                    child: ThumbnailWidget(
                      imageUrl: thumbnailUrl,
                      size: thumbnailSize.clamp(80, 140),
                      shape: ThumbnailShape.rounded,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 15 : 18,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: playBtnSize,
                            height: playBtnSize,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
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
                        ),
                      ],
                    ),
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
  final HomeLayoutMetrics metrics;
  final String? shelfId;

  const _HorizontalCardRow({
    required this.items,
    required this.metrics,
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
      scrollAmount: widget.metrics.cardWidth * 3,
      child: ListView.separated(
        key: widget.shelfId != null ? PageStorageKey(widget.shelfId) : null,
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: widget.metrics.horizontalPadding,
        ),
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
    final cardWidth = widget.metrics.cardWidth;

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
        cardWidth: cardWidth,
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
        cardWidth: cardWidth,
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
        cardWidth: cardWidth,
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
        cardWidth: cardWidth,
        heroTag: 'home_section_playlist_${item.playlistId}',
      );
    }
    if (item is PodcastDetailed) {
      return _PodcastHomeCard(
        browseId: item.browseId,
        name: item.name,
        author: item.author,
        thumbnailUrl:
            item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        cardWidth: cardWidth,
      );
    }
    if (item is EpisodeDetailed) {
      return _EpisodeHomeTile(episode: item, metrics: widget.metrics);
    }
    return const SizedBox.shrink();
  }
}

class _EpisodeHomeTile extends StatelessWidget {
  final EpisodeDetailed episode;
  final HomeLayoutMetrics metrics;

  const _EpisodeHomeTile({required this.episode, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final height = HomeLayoutMetrics.episodeShelfHeight;
    const padding = EdgeInsets.all(8);
    final contentHeight = height - padding.vertical;
    final thumbSize = contentHeight;
    final thumbnailUrl =
        episode.thumbnails.isNotEmpty ? episode.thumbnails.last.url : null;
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle =
        episode.podcastName != null && episode.podcastName!.isNotEmpty
            ? episode.podcastName!
            : (episode.date != null && episode.date!.isNotEmpty
                ? episode.date!
                : null);

    return ScaleButton(
      onTap: () => context.push('/episode/${episode.videoId}'),
      child: SizedBox(
        width: metrics.episodeTileWidth,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: thumbSize,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            episode.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PodcastHomeCard extends StatelessWidget {
  final String browseId;
  final String name;
  final String? author;
  final String? thumbnailUrl;
  final double cardWidth;

  const _PodcastHomeCard({
    required this.browseId,
    required this.name,
    this.author,
    this.thumbnailUrl,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: () => context.push('/podcast/$browseId'),
      onLongPress:
          () => ContextMenuSheet.showForPodcast(
            context,
            browseId: browseId,
            name: name,
            author: author,
            thumbnailUrl: thumbnailUrl,
          ),
      child: ShelfCardLayout(
        cardWidth: cardWidth,
        coverBuilder:
            (size) => ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: size,
              shape: ThumbnailShape.rounded,
            ),
        textBlock: [
          const SizedBox(height: 8),
          Text(
            name,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (author != null && author!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              author!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeYourPlaylists extends ConsumerWidget {
  final AsyncValue<List<dynamic>> playlistsAsync;
  final double cardWidth;
  final double horizontalPadding;

  const HomeYourPlaylists(
    this.playlistsAsync, {
    super.key,
    this.cardWidth = 140,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return playlistsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (playlists) {
        if (playlists.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + HomeLayoutMetrics.shelfTextHeight;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.yourPlaylists,
          height: height,
          horizontalPadding: horizontalPadding,
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
  final double horizontalPadding;
  final bool showHeader;
  final bool compactGrid;

  const HomeYourMixes({
    super.key,
    this.horizontalPadding = 16,
    this.showHeader = true,
    this.compactGrid = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compactGrid) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Text(
                AppLocalizations.of(context)!.yourMixes,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SmartMixCard(
                          type: SmartMixType.values[i],
                          cardWidth: constraints.maxWidth,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    final cardWidth = 140.0;
    final height = cardWidth + HomeLayoutMetrics.shelfTextHeight;
    return _HomeCarouselSection(
      title: AppLocalizations.of(context)!.yourMixes,
      height: height,
      horizontalPadding: horizontalPadding,
      itemCount: 3,
      itemBuilder: (context, index) {
        final type = SmartMixType.values[index];
        return SmartMixCard(type: type, cardWidth: cardWidth);
      },
      onShowAll: () {
        ref.read(libraryActiveTabProvider.notifier).update(5);
        context.go('/library');
      },
    );
  }
}

class HomeExplore extends StatelessWidget {
  final double horizontalPadding;
  final bool showTitle;

  const HomeExplore({
    super.key,
    this.horizontalPadding = 16,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final items = [
      (title: l10n.charts, route: '/charts', icon: LucideIcons.trophy),
      (title: l10n.moodsAndGenres, route: '/moods', icon: LucideIcons.sparkles),
      (
        title: l10n.newReleases,
        route: '/new-releases',
        icon: LucideIcons.disc3,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.explore,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return ActionChip(
                  avatar: Icon(item.icon, size: 18, color: colorScheme.primary),
                  label: Text(item.title),
                  onPressed: () => context.push(item.route),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeYourArtists extends ConsumerWidget {
  final AsyncValue<List<FollowedArtistModel>> artistsAsync;
  final double avatarSize;
  final double horizontalPadding;

  const HomeYourArtists(
    this.artistsAsync, {
    super.key,
    this.avatarSize = 64,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return artistsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        final height = avatarSize + 36;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.yourArtists,
          height: height,
          horizontalPadding: horizontalPadding,
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return _HomeArtistAvatar(
              artistId: artist.artistId,
              name: artist.name,
              thumbnailUrl: artist.thumbnailUrl,
              avatarSize: avatarSize,
              heroTag: 'home_your_artists_${artist.artistId}',
            );
          },
          onShowAll: () {
            ref.read(libraryActiveTabProvider.notifier).update(1);
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
  final double horizontalPadding;
  final bool useGrid;
  final int gridColumns;
  final int gridMaxItems;
  final double gridSpacing;

  const HomeLikedAlbums(
    this.albumsAsync, {
    super.key,
    this.cardWidth = 140,
    this.horizontalPadding = 16,
    this.useGrid = false,
    this.gridColumns = 3,
    this.gridMaxItems = 6,
    this.gridSpacing = 12,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return albumsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (albums) {
        if (albums.isEmpty) return const SizedBox.shrink();

        if (useGrid) {
          final gridAlbums = albums.take(gridMaxItems).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeSectionHeader(
                title: AppLocalizations.of(context)!.likedAlbumsHome,
                horizontalPadding: horizontalPadding,
                onShowAll: () {
                  ref.read(libraryActiveTabProvider.notifier).update(3);
                  context.go('/library');
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _HomeAlbumGrid(
                  albums: gridAlbums,
                  cardWidth: cardWidth,
                  columns: gridColumns,
                  spacing: gridSpacing,
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }

        final height = cardWidth + HomeLayoutMetrics.shelfTextHeight;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.likedAlbumsHome,
          height: height,
          horizontalPadding: horizontalPadding,
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
            ref.read(libraryActiveTabProvider.notifier).update(3);
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
  final double horizontalPadding;

  const HomeNewReleases(
    this.albumsAsync, {
    super.key,
    this.cardWidth = 140,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return albumsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + HomeLayoutMetrics.shelfTextHeight;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.newReleases,
          height: height,
          horizontalPadding: horizontalPadding,
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
  final double horizontalPadding;

  const HomeDiscover(
    this.discoverAsync, {
    super.key,
    this.cardWidth = 140,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return discoverAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        final height = cardWidth + HomeLayoutMetrics.shelfTextHeight;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.discover,
          height: height,
          horizontalPadding: horizontalPadding,
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

class HomeArtistsSimilarRow extends StatelessWidget {
  final AsyncValue<List<FollowedArtistModel>> artistsAsync;
  final AsyncValue<List<ArtistDetailed>> similarArtistsAsync;
  final double avatarSize;
  final double horizontalPadding;
  final double zoneGap;

  const HomeArtistsSimilarRow({
    super.key,
    required this.artistsAsync,
    required this.similarArtistsAsync,
    required this.avatarSize,
    required this.horizontalPadding,
    required this.zoneGap,
  });

  @override
  Widget build(BuildContext context) {
    final hasArtists = asyncListHasContent(artistsAsync);
    final hasSimilar = asyncListHasContent(similarArtistsAsync);

    if (!hasArtists && !hasSimilar) return const SizedBox.shrink();

    if (hasArtists && hasSimilar) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HomeYourArtists(
                artistsAsync,
                avatarSize: avatarSize,
                horizontalPadding: 0,
              ),
            ),
            SizedBox(width: zoneGap),
            Expanded(
              child: HomeSimilarArtists(
                similarArtistsAsync,
                avatarSize: avatarSize,
                horizontalPadding: 0,
              ),
            ),
          ],
        ),
      );
    }

    if (hasArtists) {
      return HomeYourArtists(
        artistsAsync,
        avatarSize: avatarSize,
        horizontalPadding: horizontalPadding,
      );
    }

    return HomeSimilarArtists(
      similarArtistsAsync,
      avatarSize: avatarSize,
      horizontalPadding: horizontalPadding,
    );
  }
}

class HomeSimilarArtists extends StatelessWidget {
  final AsyncValue<List<ArtistDetailed>> artistsAsync;
  final double avatarSize;
  final double horizontalPadding;
  final bool showHeader;

  const HomeSimilarArtists(
    this.artistsAsync, {
    super.key,
    this.avatarSize = 64,
    this.horizontalPadding = 16,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return artistsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        final height = avatarSize + 36;
        return _HomeCarouselSection(
          title: AppLocalizations.of(context)!.similarArtistsHome,
          height: height,
          horizontalPadding: horizontalPadding,
          showHeader: showHeader,
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return _HomeArtistAvatar(
              artistId: artist.artistId,
              name: artist.name,
              thumbnailUrl:
                  artist.thumbnails.isNotEmpty
                      ? artist.thumbnails.last.url
                      : null,
              avatarSize: avatarSize,
              heroTag: 'home_similar_artists_${artist.artistId}',
            );
          },
        );
      },
    );
  }
}

class _HomeArtistAvatar extends ConsumerWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final double avatarSize;
  final String? heroTag;

  const _HomeArtistAvatar({
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    required this.avatarSize,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = heroTag ?? 'home_artist_$artistId';

    return ScaleButton(
      onTap:
          () => context.push(
            '/artist/$artistId?heroTag=${Uri.encodeComponent(tag)}',
          ),
      onLongPress:
          () => ContextMenuSheet.showForArtist(
            context,
            artistId: artistId,
            name: name,
            thumbnailUrl: thumbnailUrl,
          ),
      child: SizedBox(
        width: avatarSize + 8,
        child: Column(
          children: [
            Hero(
              tag: tag,
              child: ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: avatarSize,
                shape: ThumbnailShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final double horizontalPadding;
  final VoidCallback? onShowAll;

  const _HomeSectionHeader({
    required this.title,
    required this.horizontalPadding,
    this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final showAllLabel = isIt ? 'Vedi tutto' : 'Show all';

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
    );
  }
}

class _HomeAlbumGrid extends StatelessWidget {
  final List<LikedAlbumModel> albums;
  final double cardWidth;
  final int columns;
  final double spacing;

  const _HomeAlbumGrid({
    required this.albums,
    required this.cardWidth,
    required this.columns,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap =
            columns > 1
                ? ((constraints.maxWidth - columns * cardWidth) / (columns - 1))
                    .clamp(spacing, double.infinity)
                : 0.0;

        final rows = <Widget>[];
        for (var i = 0; i < albums.length; i += columns) {
          final chunk = albums.skip(i).take(columns).toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: i + columns < albums.length ? spacing : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < chunk.length; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    AlbumCard(
                      albumId: chunk[j].albumId,
                      name: chunk[j].name,
                      artist: chunk[j].artistName,
                      artistId: chunk[j].artistId,
                      thumbnailUrl: chunk[j].thumbnailUrl,
                      year: chunk[j].year,
                      cardWidth: cardWidth,
                      heroTag: 'home_liked_album_${chunk[j].albumId}',
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

class _HomeCarouselSection extends StatefulWidget {
  final String title;
  final double height;
  final double horizontalPadding;
  final bool showHeader;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback? onShowAll;

  const _HomeCarouselSection({
    required this.title,
    required this.height,
    this.horizontalPadding = 16,
    this.showHeader = true,
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
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader)
          _HomeSectionHeader(
            title: widget.title,
            horizontalPadding: widget.horizontalPadding,
            onShowAll: widget.onShowAll,
          ),
        SizedBox(
          height: widget.height,
          child: HoverCarouselArrows(
            controller: _scrollController,
            scrollAmount: 300.0,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
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
  final double horizontalPadding;

  const HomeChipsBar({super.key, this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(homeBaseResultProvider);

    return resultAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final chips = data.chips;

        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 8,
            ),
            itemCount: chips.length + 1,
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

              final chip = chips[index - 1];
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
    final homeResultAsync = ref.watch(homeBaseResultProvider);

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
