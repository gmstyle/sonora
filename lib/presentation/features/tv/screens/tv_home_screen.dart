import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../home/providers/home_provider.dart';
import '../../library/providers/library_provider.dart';
import '../providers/tv_spotlight_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_category_card.dart';
import '../widgets/tv_featured_card.dart';
import '../widgets/tv_hero_spotlight.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_shelf.dart';
import '../widgets/tv_shimmer.dart';

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
    final recentAsync = ref.watch(recentHistoryProvider);
    final playlistsAsync = ref.watch(homeRandomPlaylistsProvider);
    final newReleasesAsync = ref.watch(homeRandomNewReleasesProvider);
    final selectedParams = ref.watch(homeSelectedChipParamsProvider);
    final offline = ref.watch(isOfflineProvider);
    final l10n = AppLocalizations.of(context)!;

    if (offline) {
      final recent = recentAsync.asData?.value ?? const <HistoryModel>[];
      final playlists = playlistsAsync.asData?.value ?? const <dynamic>[];
      return CustomScrollView(
        slivers: [
          if (recent.isNotEmpty)
            SliverToBoxAdapter(
              child: _TvFeaturedRow(items: recent.take(8).toList()),
            ),
          const SliverToBoxAdapter(child: _TvSmartMixShelf()),
          if (playlists.isNotEmpty)
            SliverToBoxAdapter(
              child: _TvYourPlaylistsShelf(playlists: playlists),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      );
    }

    return baseAsync.when(
      loading: () => const TvHomeShimmer(),
      error: (e, _) => ErrorRetryWidget(
        message: l10n.failedToLoadHomeFeed,
        onRetry: () {
          ref.invalidate(homeBaseResultProvider);
          ref.invalidate(homeEditorialSectionsProvider);
        },
      ),
      data: (base) {
        final recent = recentAsync.asData?.value ?? const <HistoryModel>[];
        final playlists = playlistsAsync.asData?.value ?? const <dynamic>[];
        final newReleases =
            newReleasesAsync.asData?.value ?? const <AlbumDetailed>[];
        final hasRecent = recent.isNotEmpty;
        final featured = selectedParams == null
            ? (hasRecent
                  ? recent.take(8).toList()
                  : (base.sections.isNotEmpty
                        ? base.sections.first.contents.take(8).toList()
                        : const <dynamic>[]))
            : const <dynamic>[];
        // Show sections[0] (e.g. Quick Picks for signed-in users) as its own
        // shelf when history already populates Featured, or if it has > 8 items.
        final showFirstSectionShelf =
            selectedParams == null &&
            base.sections.isNotEmpty &&
            base.sections.first.contents.isNotEmpty &&
            (hasRecent || base.sections.first.contents.length > 8);

        return CustomScrollView(
          slivers: [
            if (selectedParams == null)
              const SliverToBoxAdapter(child: TvHeroSpotlight()),
            if (featured.isNotEmpty)
              SliverToBoxAdapter(child: _TvFeaturedRow(items: featured)),
            if (base.chips.isNotEmpty)
              SliverToBoxAdapter(
                child: _TvCategoryRow(
                  chips: base.chips,
                  selectedParams: selectedParams,
                ),
              ),
            if (selectedParams == null) ...[
              const SliverToBoxAdapter(child: _TvSmartMixShelf()),
              if (playlists.isNotEmpty)
                SliverToBoxAdapter(
                  child: _TvYourPlaylistsShelf(playlists: playlists),
                ),
              if (showFirstSectionShelf)
                SliverToBoxAdapter(
                  child: _TvHomeSectionShelf(section: base.sections.first),
                ),
              if (newReleases.isNotEmpty)
                SliverToBoxAdapter(
                  child: _TvHomeSectionShelf(
                    section: HomeSection(
                      title: l10n.newReleases,
                      contents: newReleases,
                    ),
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: sectionsAsync.when(
                loading: () => const TvShelfShimmer(count: 2),
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
            badge: data.tag,
            autofocus: cards.isEmpty,
            onLeftAtEdge: cards.isEmpty
                ? () => TvShellFocus.requestSidebar(context)
                : null,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                ref
                    .read(tvSpotlightProvider.notifier)
                    .setSpotlight(
                      TvSpotlightData(
                        title: data.title,
                        subtitle: data.subtitle,
                        imageUrl: data.imageUrl,
                        tag: data.tag ?? l10n.home,
                        onPlay: data.onSelect,
                        onOpen: data.onOpen,
                      ),
                    );
              }
            },
            onSelect: data.onSelect,
            onLongSelect: data.onLongSelect,
          ),
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    // Seed the spotlight with the first featured item on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(tvSpotlightProvider) == null && items.isNotEmpty) {
        final first = _featuredData(context, ref, items.first, l10n);
        if (first != null) {
          ref
              .read(tvSpotlightProvider.notifier)
              .setSpotlight(
                TvSpotlightData(
                  title: first.title,
                  subtitle: first.subtitle,
                  imageUrl: first.imageUrl,
                  tag: first.tag ?? l10n.home,
                  onPlay: first.onSelect,
                  onOpen: first.onOpen,
                ),
              );
        }
      }
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.shelfGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvSectionHeader(
            title: l10n.continueListening,
            accentColor: theme.colorScheme.primary,
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
    if (item is HistoryModel) {
      final isEpisode = item.contentType == 'episode';
      return _FeaturedData(
        title: item.title,
        subtitle: item.artist,
        imageUrl: item.thumbnailUrl,
        tag: isEpisode ? l10n.episode : l10n.recentlyPlayed,
        onSelect: () {
          if (isEpisode) {
            context.push('/episode/${item.videoId}');
            return;
          }
          ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                item.videoId,
                isVideo: item.isVideo,
                isExplicit: item.isExplicit,
              );
        },
        onOpen: item.podcastBrowseId != null
            ? () => context.push('/podcast/${item.podcastBrowseId}')
            : null,
        onLongSelect: () {
          if (isEpisode) {
            ContextMenuSheet.showForEpisode(
              context,
              videoId: item.videoId,
              name: item.title,
              podcastName: item.artist,
              podcastBrowseId: item.podcastBrowseId,
              thumbnailUrl: item.thumbnailUrl,
            );
            return;
          }
          ContextMenuSheet.showForSong(
            context,
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            thumbnailUrl: item.thumbnailUrl,
            duration: item.duration,
            isVideo: item.isVideo,
            isExplicit: item.isExplicit,
          );
        },
      );
    }
    if (item is SongDetailed || item is VideoDetailed) {
      final song = item as dynamic;
      final isVid = item is VideoDetailed || song.type == 'VIDEO';
      final artUrl = (song.thumbnails as List).isNotEmpty
          ? song.thumbnails.last.url as String
          : null;
      return _FeaturedData(
        title: song.name as String,
        subtitle: displayArtists(song.artists as List<ArtistBasic>),
        imageUrl: artUrl,
        tag: l10n.topSongs,
        onSelect: () {
          ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                song.videoId as String,
                isVideo: isVid,
                isExplicit: song.isExplicit as bool? ?? false,
              );
        },
        onLongSelect: () => ContextMenuSheet.showForSong(
          context,
          videoId: song.videoId as String,
          title: song.name as String,
          artist: displayArtists(song.artists as List<ArtistBasic>),
          artists: song.artists as List<ArtistBasic>,
          thumbnailUrl: artUrl,
          isVideo: isVid,
          isExplicit: song.isExplicit as bool? ?? false,
        ),
      );
    }
    if (item is AlbumDetailed) {
      final artUrl = item.thumbnails.isNotEmpty
          ? item.thumbnails.last.url
          : null;
      return _FeaturedData(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: artUrl,
        tag: l10n.entityKindAlbum,
        onSelect: () => context.push('/album/${item.albumId}'),
        onOpen: () => context.push('/album/${item.albumId}'),
        onLongSelect: () => ContextMenuSheet.showForAlbum(
          context,
          albumId: item.albumId,
          name: item.name,
          artist: displayArtists(item.artists),
          artistId: primaryArtistId(item.artists),
          thumbnailUrl: artUrl,
          year: item.year,
        ),
      );
    }
    if (item is PlaylistDetailed) {
      final artUrl = item.thumbnails.isNotEmpty
          ? item.thumbnails.last.url
          : null;
      return _FeaturedData(
        title: item.name,
        subtitle: displayArtists(item.artists),
        imageUrl: artUrl,
        tag: l10n.entityKindPlaylist,
        onSelect: () => context.push('/playlist/${item.playlistId}'),
        onOpen: () => context.push('/playlist/${item.playlistId}'),
        onLongSelect: () => ContextMenuSheet.showForPlaylist(
          context,
          playlistId: item.playlistId,
          name: item.name,
          thumbnailUrl: artUrl,
        ),
      );
    }
    return null;
  }
}

class _FeaturedData {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? tag;
  final VoidCallback onSelect;
  final VoidCallback? onOpen;
  final VoidCallback? onLongSelect;

  const _FeaturedData({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.tag,
    required this.onSelect,
    this.onOpen,
    this.onLongSelect,
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
          TvSectionHeader(
            title: l10n.moodsAndGenres,
            accentColor: theme.colorScheme.secondary,
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
    return TvShelf(
      title: section.title,
      accentColor: const Color(0xFF2DD4BF),
      children: cards,
    );
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
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            ref
                .read(tvSpotlightProvider.notifier)
                .setSpotlight(
                  TvSpotlightData(
                    title: song.name,
                    subtitle: displayArtists(song.artists),
                    imageUrl: song.thumbnails.isNotEmpty
                        ? song.thumbnails.last.url
                        : null,
                    tag: section.title,
                    onPlay: () {
                      ref
                          .read(playerStateProvider.notifier)
                          .playVideoId(
                            song.videoId,
                            isVideo:
                                item is VideoDetailed || song.type == 'VIDEO',
                            isExplicit: song.isExplicit,
                          );
                    },
                  ),
                );
          }
        },
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
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            ref
                .read(tvSpotlightProvider.notifier)
                .setSpotlight(
                  TvSpotlightData(
                    title: item.name,
                    subtitle: displayArtists(item.artists),
                    imageUrl: item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null,
                    tag: section.title,
                    onPlay: () => context.push('/album/${item.albumId}'),
                    onOpen: () => context.push('/album/${item.albumId}'),
                  ),
                );
          }
        },
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
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            ref
                .read(tvSpotlightProvider.notifier)
                .setSpotlight(
                  TvSpotlightData(
                    title: item.name,
                    subtitle: displayArtists(item.artists),
                    imageUrl: item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null,
                    tag: section.title,
                    onPlay: () => context.push('/playlist/${item.playlistId}'),
                    onOpen: () => context.push('/playlist/${item.playlistId}'),
                  ),
                );
          }
        },
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
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            ref
                .read(tvSpotlightProvider.notifier)
                .setSpotlight(
                  TvSpotlightData(
                    title: item.name,
                    subtitle: item.author,
                    imageUrl: item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null,
                    tag: section.title,
                    onPlay: () => context.push('/podcast/${item.browseId}'),
                    onOpen: () => context.push('/podcast/${item.browseId}'),
                  ),
                );
          }
        },
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
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            ref
                .read(tvSpotlightProvider.notifier)
                .setSpotlight(
                  TvSpotlightData(
                    title: item.name,
                    subtitle: item.podcastName,
                    imageUrl: item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null,
                    tag: section.title,
                    onPlay: () => context.push('/episode/${item.videoId}'),
                    onOpen: () => context.push('/episode/${item.videoId}'),
                  ),
                );
          }
        },
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
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            ref
                .read(tvSpotlightProvider.notifier)
                .setSpotlight(
                  TvSpotlightData(
                    title: item.name,
                    subtitle: null,
                    imageUrl: item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null,
                    tag: section.title,
                    onPlay: () => context.push('/artist/${item.artistId}'),
                    onOpen: () => context.push('/artist/${item.artistId}'),
                  ),
                );
          }
        },
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

class _TvSmartMixShelf extends ConsumerWidget {
  const _TvSmartMixShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return TvShelf(
      title: l10n.yourMixes,
      children: [
        for (final type in SmartMixType.values)
          Builder(
            builder: (context) {
              final (title, subtitle) = switch (type) {
                SmartMixType.mostPlayed => (
                  l10n.mostPlayed,
                  l10n.mostPlayedDesc,
                ),
                SmartMixType.recentlyPlayed => (
                  l10n.recentlyPlayed,
                  l10n.recentlyPlayedDesc,
                ),
                SmartMixType.forgottenFavorites => (
                  l10n.forgottenFavorites,
                  l10n.forgottenFavoritesDesc,
                ),
              };
              return TvPosterCard(
                title: title,
                subtitle: subtitle,
                placeholderOverride: Container(
                  decoration: BoxDecoration(
                    gradient: smartMixGradient(context, type),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.sparkles,
                      size: 36,
                      color: SonoraPulseTokens.onBrandGraphic,
                    ),
                  ),
                ),
                onFocusChange: (hasFocus) {
                  if (!hasFocus) return;
                  ref
                      .read(tvSpotlightProvider.notifier)
                      .setSpotlight(
                        TvSpotlightData(
                          title: title,
                          subtitle: subtitle,
                          tag: l10n.yourMixes,
                          onPlay: () => context.push('/smart-mix/${type.name}'),
                          onOpen: () => context.push('/smart-mix/${type.name}'),
                        ),
                      );
                },
                onSelect: () => context.push('/smart-mix/${type.name}'),
              );
            },
          ),
      ],
    );
  }
}

class _TvYourPlaylistsShelf extends ConsumerWidget {
  final List<dynamic> playlists;

  const _TvYourPlaylistsShelf({required this.playlists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final cards = <Widget>[];

    for (final item in playlists) {
      if (item is LocalPlaylistModel) {
        void playLocal() async {
          final entries = await ref.read(
            playlistEntriesProvider(item.id).future,
          );
          if (entries.isEmpty) return;
          await ref
              .read(playerStateProvider.notifier)
              .playLocalPlaylist(entries, startIndex: 0);
        }

        cards.add(
          TvPosterCard(
            title: item.name,
            placeholderOverride: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.listMusic,
                  size: 36,
                  color: SonoraPulseTokens.onBrandGraphic,
                ),
              ),
            ),
            onFocusChange: (hasFocus) {
              if (!hasFocus) return;
              ref
                  .read(tvSpotlightProvider.notifier)
                  .setSpotlight(
                    TvSpotlightData(
                      title: item.name,
                      tag: l10n.yourPlaylists,
                      onPlay: playLocal,
                    ),
                  );
            },
            onSelect: playLocal,
            onLongSelect: () => ContextMenuSheet.showForCustomPlaylist(
              context,
              playlist: item,
              onUpdated: () {},
            ),
          ),
        );
      } else if (item is LikedPlaylistModel) {
        cards.add(
          TvPosterCard(
            title: item.name,
            imageUrl: item.thumbnailUrl,
            onFocusChange: (hasFocus) {
              if (!hasFocus) return;
              ref
                  .read(tvSpotlightProvider.notifier)
                  .setSpotlight(
                    TvSpotlightData(
                      title: item.name,
                      imageUrl: item.thumbnailUrl,
                      tag: l10n.yourPlaylists,
                      onPlay: () =>
                          context.push('/playlist/${item.playlistId}'),
                      onOpen: () =>
                          context.push('/playlist/${item.playlistId}'),
                    ),
                  );
            },
            onSelect: () => context.push('/playlist/${item.playlistId}'),
            onLongSelect: () => ContextMenuSheet.showForPlaylist(
              context,
              playlistId: item.playlistId,
              name: item.name,
              thumbnailUrl: item.thumbnailUrl,
            ),
          ),
        );
      }
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return TvShelf(title: l10n.yourPlaylists, children: cards);
  }
}
