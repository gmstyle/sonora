import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../home/providers/home_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_hero.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_shelf.dart';

/// TV catalog browser: hero + mood chips + horizontal shelves.
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
        child: ShimmerLoading(variant: ShimmerVariant.hero, heroHeight: 280),
      ),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadHomeFeed,
        onRetry: () {
          ref.invalidate(homeBaseResultProvider);
          ref.invalidate(homeEditorialSectionsProvider);
        },
      ),
      data: (base) {
        final heroSection = selectedParams == null && base.sections.isNotEmpty
            ? base.sections.first
            : null;
        final heroItem = heroSection?.contents.isNotEmpty == true
            ? heroSection!.contents.first
            : null;

        return CustomScrollView(
          slivers: [
            if (heroItem != null)
              SliverToBoxAdapter(
                child: _buildHero(context, ref, heroItem, l10n),
              ),
            if (!offline && base.chips.isNotEmpty)
              SliverToBoxAdapter(
                child: _TvMoodChips(
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

  Widget _buildHero(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
    AppLocalizations l10n,
  ) {
    if (item is SongDetailed || item is VideoDetailed) {
      final song = item as dynamic;
      return TvHero(
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
      return TvHero(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        primaryLabel: l10n.playAll,
        onPrimary: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return TvHero(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        primaryLabel: l10n.playAll,
        onPrimary: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _TvMoodChips extends ConsumerWidget {
  final List<BrowseChip> chips;
  final String? selectedParams;

  const _TvMoodChips({required this.chips, required this.selectedParams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          TvMetrics.contentPadding,
          16,
          TvMetrics.contentPadding,
          8,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TvFocusable(
              onSelect: () => ref
                  .read(homeSelectedChipParamsProvider.notifier)
                  .update(null),
              onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
              borderRadius: BorderRadius.circular(24),
              child: FilterChip(
                label: Text(l10n.home),
                selected: selectedParams == null,
                onSelected: (_) => ref
                    .read(homeSelectedChipParamsProvider.notifier)
                    .update(null),
              ),
            ),
          ),
          for (var i = 0; i < chips.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TvFocusable(
                onSelect: () => ref
                    .read(homeSelectedChipParamsProvider.notifier)
                    .update(chips[i].params),
                onLeftAtEdge: i == 0 && selectedParams != null
                    ? () => TvShellFocus.requestSidebar(context)
                    : null,
                borderRadius: BorderRadius.circular(24),
                child: FilterChip(
                  label: Text(chips[i].title),
                  selected: selectedParams == chips[i].params,
                  onSelected: (_) => ref
                      .read(homeSelectedChipParamsProvider.notifier)
                      .update(chips[i].params),
                ),
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
        onLongSelect: () {
          // Context menus land via entity long-press dialogs in later polish;
          // primary play stays on short select.
        },
      );
    }
    if (item is AlbumDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/album/${item.albumId}'),
      );
    }
    if (item is PlaylistDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
      );
    }
    if (item is PodcastDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: item.author,
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/podcast/${item.browseId}'),
      );
    }
    if (item is EpisodeDetailed) {
      return TvPosterCard(
        title: item.name,
        subtitle: item.podcastName,
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/episode/${item.videoId}'),
      );
    }
    if (item is ArtistDetailed) {
      return TvPosterCard(
        title: item.name,
        imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
        shape: ThumbnailShape.circle,
        onLeftAtEdge: onLeft,
        onSelect: () => context.push('/artist/${item.artistId}'),
      );
    }
    return null;
  }
}
