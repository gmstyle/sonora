import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
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
import '../widgets/tv_featured_card.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_shelf.dart';

/// ATV catalog browser — Material TV "browser" template.
///
/// Vertical stack of horizontal rows (featured → moods → shelves). Focus moves
/// down between rows and left/right within a row. Not a phone/JetFit hero page.
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
          variant: ShimmerVariant.section,
          cardWidth: TvMetrics.featuredCardWidth,
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
        final featured = selectedParams == null && base.sections.isNotEmpty
            ? base.sections.first.contents.take(8).toList()
            : const <dynamic>[];

        return CustomScrollView(
          slivers: [
            if (featured.isNotEmpty)
              SliverToBoxAdapter(child: _TvFeaturedRow(items: featured)),
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

class _TvFeaturedRow extends ConsumerWidget {
  final List<dynamic> items;

  const _TvFeaturedRow({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cards = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final data = _featuredData(context, ref, items[i], l10n);
      if (data == null) continue;
      cards.add(
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TvFeaturedCard(
            title: data.title,
            subtitle: data.subtitle,
            imageUrl: data.imageUrl,
            autofocus: cards.isEmpty,
            onLeftAtEdge: cards.isEmpty
                ? () => TvShellFocus.requestSidebar(context)
                : null,
            onSelect: data.onSelect,
          ),
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.shelfGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.contentPadding,
              TvMetrics.browseTopPadding,
              TvMetrics.contentPadding,
              TvMetrics.shelfTitleGap,
            ),
            child: Text(
              l10n.home,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: TvMetrics.featuredRowHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: TvMetrics.contentPadding,
                vertical: 8,
              ),
              children: cards,
            ),
          ),
        ],
      ),
    );
  }

  _FeaturedData? _featuredData(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
    AppLocalizations l10n,
  ) {
    if (item is SongDetailed || item is VideoDetailed) {
      final song = item as dynamic;
      return _FeaturedData(
        title: song.name as String,
        subtitle: displayArtists(song.artists as List<ArtistBasic>),
        imageUrl: (song.thumbnails as List).isNotEmpty
            ? song.thumbnails.last.url as String
            : null,
        onSelect: () {
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
      return _FeaturedData(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onSelect: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return _FeaturedData(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return null;
  }
}

class _FeaturedData {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback onSelect;

  const _FeaturedData({
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.onSelect,
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
              4,
              TvMetrics.contentPadding,
              TvMetrics.shelfTitleGap,
            ),
            child: Text(
              l10n.moodsAndGenres,
              style: theme.textTheme.titleLarge?.copyWith(
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
