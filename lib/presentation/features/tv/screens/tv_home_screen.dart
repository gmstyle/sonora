import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../home/providers/home_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_category_card.dart';
import '../widgets/tv_hero.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_shelf.dart';

/// TV catalog browser: JetFit hero card + category row + horizontal shelves.
class TvHomeScreen extends ConsumerWidget {
  const TvHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseAsync = ref.watch(homeBaseResultProvider);
    final sectionsAsync = ref.watch(homeEditorialSectionsProvider);
    final selectedParams = ref.watch(homeSelectedChipParamsProvider);
    final offline = ref.watch(isOfflineProvider);
    final l10n = AppLocalizations.of(context)!;

    return baseAsync.when(
      loading: () => const Center(
        child: ShimmerLoading(
          variant: ShimmerVariant.hero,
          heroHeight: TvMetrics.heroCardHeight,
        ),
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadHomeFeed,
        onRetry: () {
          ref.invalidate(homeBaseResultProvider);
          ref.invalidate(homeEditorialSectionsProvider);
        },
      ),
      data: (base) {
        final heroItems = selectedParams == null && base.sections.isNotEmpty
            ? base.sections.first.contents.take(5).toList()
            : const <dynamic>[];

        return CustomScrollView(
          slivers: [
            if (heroItems.isNotEmpty)
              SliverToBoxAdapter(child: _TvHeroCarousel(items: heroItems)),
            if (!offline && base.chips.isNotEmpty)
              SliverToBoxAdapter(
                child: _TvCategoryRow(
                  chips: base.chips,
                  selectedParams: selectedParams,
                ),
              ),
            SliverToBoxAdapter(
              child: sectionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(TvMetrics.contentPadding),
                  child: ShimmerLoading(
                    variant: ShimmerVariant.section,
                    cardWidth: TvMetrics.shelfCardWidth,
                  ),
                ),
                error: (e, _) => ErrorRetryWidget(
                  message: l10n.failedToLoadHomeFeed,
                  onRetry: () => ref.invalidate(homeEditorialSectionsProvider),
                ),
                data: (sections) => Column(
                  children: [
                    for (final section in sections)
                      _TvHomeSectionShelf(section: section),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TvHeroCarousel extends ConsumerStatefulWidget {
  final List<dynamic> items;

  const _TvHeroCarousel({required this.items});

  @override
  ConsumerState<_TvHeroCarousel> createState() => _TvHeroCarouselState();
}

class _TvHeroCarouselState extends ConsumerState<_TvHeroCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.items[_index.clamp(0, widget.items.length - 1)];
    final data = _heroData(context, ref, item, l10n);
    if (data == null) return const SizedBox.shrink();

    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            _index < widget.items.length - 1) {
          setState(() => _index++);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _index > 0) {
          setState(() => _index--);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TvHero(
        title: data.title,
        subtitle: data.subtitle,
        imageUrl: data.imageUrl,
        primaryLabel: data.primaryLabel,
        onPrimary: data.onPrimary,
        pageIndex: _index,
        pageCount: widget.items.length,
        onLeftAtEdge: () {
          if (_index > 0) {
            setState(() => _index--);
          } else {
            TvShellFocus.requestSidebar(context);
          }
        },
      ),
    );
  }

  _HeroData? _heroData(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
    AppLocalizations l10n,
  ) {
    if (item is SongDetailed || item is VideoDetailed) {
      final song = item as dynamic;
      return _HeroData(
        title: song.name as String,
        subtitle: displayArtists(song.artists as List<ArtistBasic>),
        imageUrl: (song.thumbnails as List).isNotEmpty
            ? song.thumbnails.last.url as String
            : null,
        primaryLabel: l10n.playNow,
        onPrimary: () {
          ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                song.videoId as String,
                isVideo: item is VideoDetailed || song.type == 'VIDEO',
                isExplicit: song.isExplicit as bool? ?? false,
              );
        },
      );
    }
    if (item is AlbumDetailed) {
      return _HeroData(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        primaryLabel: l10n.playAll,
        onPrimary: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return _HeroData(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        primaryLabel: l10n.playAll,
        onPrimary: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return null;
  }
}

class _HeroData {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _HeroData({
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.primaryLabel,
    required this.onPrimary,
  });
}

class _TvCategoryRow extends ConsumerWidget {
  final List<BrowseChip> chips;
  final String? selectedParams;

  const _TvCategoryRow({required this.chips, required this.selectedParams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.shelfGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.contentPadding,
              12,
              TvMetrics.contentPadding,
              TvMetrics.shelfTitleGap,
            ),
            child: Text(
              l10n.moodsAndGenres,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: TvMetrics.categoryRowHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: TvMetrics.contentPadding,
                vertical: 8,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TvCategoryCard(
                    title: l10n.home,
                    selected: selectedParams == null,
                    onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                    onSelect: () => ref
                        .read(homeSelectedChipParamsProvider.notifier)
                        .update(null),
                  ),
                ),
                for (var i = 0; i < chips.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TvCategoryCard(
                      title: chips[i].title,
                      selected: selectedParams == chips[i].params,
                      onLeftAtEdge: i == 0 && selectedParams != null
                          ? () => TvShellFocus.requestSidebar(context)
                          : null,
                      onSelect: () => ref
                          .read(homeSelectedChipParamsProvider.notifier)
                          .update(chips[i].params),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvHomeSectionShelf extends ConsumerWidget {
  final HomeSection section;

  const _TvHomeSectionShelf({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <Widget>[];
    for (var i = 0; i < section.contents.length; i++) {
      final item = section.contents[i];
      final card = _cardFor(context, ref, item, isLeading: i == 0);
      if (card != null) cards.add(card);
    }
    return TvShelf(title: section.title, children: cards);
  }

  Widget? _cardFor(
    BuildContext context,
    WidgetRef ref,
    dynamic item, {
    required bool isLeading,
  }) {
    final onLeft = isLeading
        ? () => TvShellFocus.requestSidebar(context)
        : null;

    if (item is SongDetailed || item is VideoDetailed) {
      final song = item;
      return TvPosterCard(
        title: song.name,
        subtitle: displayArtists(song.artists),
        imageUrl: song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () {
          ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                song.videoId,
                isVideo: item is VideoDetailed || song.type == 'VIDEO',
                isExplicit: song.isExplicit,
              );
        },
        onLongSelect: () => ContextMenuSheet.showForSong(
          context,
          videoId: song.videoId,
          title: song.name,
          artist: displayArtists(song.artists),
          artists: song.artists,
          thumbnailUrl: song.thumbnails.isNotEmpty
              ? song.thumbnails.last.url
              : null,
          isVideo: item is VideoDetailed || song.type == 'VIDEO',
          isExplicit: song.isExplicit,
          isPlayable: song.isPlayable,
        ),
      );
    }
    if (item is AlbumDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/album/${item.albumId}'),
        onLongSelect: () => ContextMenuSheet.showForAlbum(
          context,
          albumId: item.albumId,
          name: item.name,
          artist: displayArtists(item.artists),
          artistId: primaryArtistId(item.artists),
          thumbnailUrl: item.thumbnails.isNotEmpty
              ? item.thumbnails.last.url
              : null,
          year: item.year,
        ),
      );
    }
    if (item is PlaylistDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
        onLongSelect: () => ContextMenuSheet.showForPlaylist(
          context,
          playlistId: item.playlistId,
          name: item.name,
          thumbnailUrl: item.thumbnails.isNotEmpty
              ? item.thumbnails.last.url
              : null,
        ),
      );
    }
    if (item is PodcastDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: item.author,
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/podcast/${item.browseId}'),
        onLongSelect: () => ContextMenuSheet.showForPodcast(
          context,
          browseId: item.browseId,
          name: item.name,
          author: item.author,
          thumbnailUrl: item.thumbnails.isNotEmpty
              ? item.thumbnails.last.url
              : null,
        ),
      );
    }
    if (item is EpisodeDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: item.podcastName,
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/episode/${item.videoId}'),
        onLongSelect: () => ContextMenuSheet.showForEpisode(
          context,
          videoId: item.videoId,
          name: item.name,
          podcastName: item.podcastName,
          podcastBrowseId: item.podcastId,
          thumbnailUrl: item.thumbnails.isNotEmpty
              ? item.thumbnails.last.url
              : null,
        ),
      );
    }
    if (item is ArtistDetailed) {
      return TvPosterCard(
        title: item.name,
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        shape: ThumbnailShape.circle,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/artist/${item.artistId}'),
        onLongSelect: () => ContextMenuSheet.showForArtist(
          context,
          artistId: item.artistId,
          name: item.name,
          thumbnailUrl: item.thumbnails.isNotEmpty
              ? item.thumbnails.last.url
              : null,
        ),
      );
    }
    return null;
  }
}
