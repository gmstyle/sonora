import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/stats_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../home/providers/home_provider.dart';
import '../../library/widgets/open_wrapped.dart';
import '../../library/widgets/playlist_detail_view.dart';
import '../tv_metrics.dart';
import '../widgets/tv_focusable.dart';
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
    final isOffline = ref.watch(isOfflineProvider);
    final stats = ref.watch(statsProvider);
    final wrappedSeen = ref.watch(
      settingsProvider.select((s) => s.wrappedSeen),
    );

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
              if (!stats.isLoading && stats.isWrappedAvailable)
                TvShelf(
                  title: l10n.wrappedTitle,
                  memoryKey: 'tv/home/wrapped',
                  height: TvMetrics.artistShelfHeight,
                  children: [
                    _TvEntryCard(
                      title:
                          wrappedSeen ? l10n.wrappedReplay : l10n.startWrapped,
                      subtitle: l10n.wrappedIntro,
                      icon: LucideIcons.partyPopper,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A1B9A), Color(0xFFFF6F00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onSelect: () => openSonoraWrapped(context, ref),
                    ),
                  ],
                ),
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
              _exploreShelf(context, l10n, isOffline: isOffline),
              _mixesShelf(context, l10n),
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
                    height: TvMetrics.artistShelfHeight,
                    children: [
                      for (final artist in artists.take(12))
                        TvPosterCard(
                          title: artist.name,
                          thumbnailUrl: artist.thumbnailUrl,
                          circular: true,
                          width: TvMetrics.artistAvatarSize,
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

  Widget _exploreShelf(
    BuildContext context,
    AppLocalizations l10n, {
    required bool isOffline,
  }) {
    final items = [
      (
        title: l10n.charts,
        route: '/charts',
        icon: LucideIcons.trophy,
        colors: const [Color(0xFFE53935), Color(0xFFFF8A65)],
      ),
      (
        title: l10n.moodsAndGenres,
        route: '/moods',
        icon: LucideIcons.palette,
        colors: const [Color(0xFF8E24AA), Color(0xFF5C6BC0)],
      ),
      (
        title: l10n.newReleases,
        route: '/new-releases',
        icon: LucideIcons.disc3,
        colors: const [Color(0xFF00897B), Color(0xFF26A69A)],
      ),
    ];
    return TvShelf(
      title: l10n.explore,
      memoryKey: 'tv/home/explore',
      height: TvMetrics.artistShelfHeight,
      children: [
        for (final item in items)
          _TvEntryCard(
            title: item.title,
            icon: item.icon,
            gradient: LinearGradient(
              colors: item.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onSelect: isOffline ? null : () => context.push(item.route),
          ),
      ],
    );
  }

  Widget _mixesShelf(BuildContext context, AppLocalizations l10n) {
    return TvShelf(
      title: l10n.yourMixes,
      memoryKey: 'tv/home/mixes',
      children: [
        _TvEntryCard(
          title: l10n.mixForThisMoment,
          subtitle: l10n.mixForThisMomentHint,
          icon: LucideIcons.sparkles,
          gradient: const LinearGradient(
            colors: [Color(0xFF5E35B1), Color(0xFFEC407A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onSelect: () => context.push('/moment-mix'),
        ),
        for (final type in SmartMixType.values)
          _TvEntryCard(
            title: _smartMixTitle(l10n, type),
            subtitle: _smartMixSubtitle(l10n, type),
            icon: _smartMixIcon(type),
            gradient: _smartMixGradient(type),
            onSelect: () => context.push('/smart-mix/${type.name}'),
          ),
      ],
    );
  }

  String _smartMixTitle(AppLocalizations l10n, SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => l10n.mostPlayed,
      SmartMixType.recentlyPlayed => l10n.recentlyPlayed,
      SmartMixType.forgottenFavorites => l10n.forgottenFavorites,
    };
  }

  String _smartMixSubtitle(AppLocalizations l10n, SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => l10n.mostPlayedDesc,
      SmartMixType.recentlyPlayed => l10n.recentlyPlayedDesc,
      SmartMixType.forgottenFavorites => l10n.forgottenFavoritesDesc,
    };
  }

  IconData _smartMixIcon(SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => LucideIcons.flame,
      SmartMixType.recentlyPlayed => LucideIcons.history,
      SmartMixType.forgottenFavorites => LucideIcons.heart,
    };
  }

  LinearGradient _smartMixGradient(SmartMixType type) {
    return switch (type) {
      SmartMixType.mostPlayed => const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFFFB300)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SmartMixType.recentlyPlayed => const LinearGradient(
        colors: [Color(0xFF3949AB), Color(0xFF8E24AA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      SmartMixType.forgottenFavorites => const LinearGradient(
        colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };
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
        width: TvMetrics.artistAvatarSize,
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

/// Gradient icon tile used for Explore and Mix D-pad entry points.
class _TvEntryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onSelect;

  const _TvEntryCard({
    required this.title,
    required this.icon,
    required this.gradient,
    this.subtitle,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onSelect != null;
    return SizedBox(
      width: TvMetrics.cardWidth,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: TvFocusable(
          enabled: enabled,
          onSelect: onSelect,
          debugLabel: 'entry:$title',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: TvMetrics.cardArtSize,
                height: TvMetrics.cardArtSize,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
