import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/app_lifecycle_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/glass_app_bar_background.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../providers/home_provider.dart';
import '../widgets/home_quick_row.dart';
import '../widgets/home_section_renderer.dart';
import '../widgets/home_zone_header.dart';
import 'home_layout_metrics.dart';

class HomeFeedLayout extends ConsumerWidget {
  final HomeLayoutSize size;

  const HomeFeedLayout({super.key, required this.size});

  HomeLayoutMetrics get metrics => HomeLayoutMetrics(size);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLifecycleProvider);
    final baseSectionsAsync = ref.watch(homeBaseSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);
    final playlistsAsync = ref.watch(homeRandomPlaylistsProvider);
    final artistsAsync = ref.watch(homeRandomArtistsProvider);
    final albumsAsync = ref.watch(homeRandomAlbumsProvider);
    final newReleasesAsync = ref.watch(homeRandomNewReleasesProvider);
    final discoverAsync = ref.watch(homeDiscoverProvider);
    final similarArtistsAsync = ref.watch(homeSimilarArtistsProvider);
    final hideDiscoverHero = ref.watch(homeSelectedChipParamsProvider) != null;
    final isOffline = ref.watch(isOfflineProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: const GlassAppBarBackground(),
        title: Row(
          spacing: 8,
          children: [
            const SonoraLogo.icon(22),
            Text(
              _getGreeting(context),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (Platform.isLinux)
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              tooltip: l10n.refresh,
              onPressed: () => _invalidateHome(ref),
            ),
        ],
      ),
      body: AmbientBackground(
        child:
            isOffline
                ? RefreshIndicator(
                  onRefresh: () => _refreshOffline(ref),
                  child: ListView(
                    padding: _listPadding(context),
                    children: [
                      _OfflineBanner(metrics: metrics),
                      ..._buildRiprendiZone(historyAsync: historyAsync),
                      ..._buildYourMusicZone(
                        l10n: l10n,
                        playlistsAsync: playlistsAsync,
                        artistsAsync: artistsAsync,
                        albumsAsync: albumsAsync,
                        similarArtistsAsync: similarArtistsAsync,
                        includeSimilarInMusicZone: false,
                      ),
                    ],
                  ),
                )
                : baseSectionsAsync.when(
                  loading: () => HomeShimmer(metrics: metrics),
                  error:
                      (_, _) => ErrorRetryWidget(
                        message: l10n.failedToLoadHomeFeed,
                        onRetry: () => ref.invalidate(homeBaseResultProvider),
                      ),
                  data:
                      (sections) => RefreshIndicator(
                        onRefresh: () => _refreshHome(ref),
                        child: ListView(
                          padding: _listPadding(context),
                          children: [
                            ..._buildRiprendiZone(historyAsync: historyAsync),
                            ..._buildYourMusicZone(
                              l10n: l10n,
                              playlistsAsync: playlistsAsync,
                              artistsAsync: artistsAsync,
                              albumsAsync: albumsAsync,
                              similarArtistsAsync: similarArtistsAsync,
                              includeSimilarInMusicZone:
                                  metrics.useSideBySideArtists,
                            ),
                            ..._buildDiscoverZone(
                              context: context,
                              l10n: l10n,
                              sections: sections,
                              newReleasesAsync: newReleasesAsync,
                              discoverAsync: discoverAsync,
                              similarArtistsAsync: similarArtistsAsync,
                              showHero: !hideDiscoverHero,
                              showSimilarArtists: !metrics.useSideBySideArtists,
                            ),
                            HomeEditorialZone(metrics: metrics),
                          ],
                        ),
                      ),
                ),
      ),
    );
  }

  EdgeInsets _listPadding(BuildContext context) {
    return EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
      bottom: MediaQuery.of(context).padding.bottom + 16,
    );
  }

  List<Widget> _buildRiprendiZone({required AsyncValue historyAsync}) {
    final showQuickRow =
        asyncHistoryHasContent(historyAsync) || HomeQuickRow.mixesHasContent();
    if (!showQuickRow) return const [];

    return [HomeQuickRow(historyAsync: historyAsync, metrics: metrics)];
  }

  List<Widget> _buildYourMusicZone({
    required AppLocalizations l10n,
    required AsyncValue<List<dynamic>> playlistsAsync,
    required AsyncValue<List<FollowedArtistModel>> artistsAsync,
    required AsyncValue<List<LikedAlbumModel>> albumsAsync,
    required AsyncValue<List<ArtistDetailed>> similarArtistsAsync,
    required bool includeSimilarInMusicZone,
  }) {
    final hasPlaylists = asyncListHasContent(playlistsAsync);
    final hasArtists = asyncListHasContent(artistsAsync);
    final hasAlbums = asyncListHasContent(albumsAsync);
    final hasSimilar = asyncListHasContent(similarArtistsAsync);
    final hasArtistsBlock =
        includeSimilarInMusicZone ? (hasArtists || hasSimilar) : hasArtists;

    if (!hasPlaylists && !hasArtistsBlock && !hasAlbums) return const [];

    return [
      HomeZoneHeader(title: l10n.yourMusicZone, metrics: metrics),
      HomeYourPlaylists(
        playlistsAsync,
        cardWidth: metrics.cardWidth,
        horizontalPadding: metrics.horizontalPadding,
      ),
      if (includeSimilarInMusicZone)
        HomeArtistsSimilarRow(
          artistsAsync: artistsAsync,
          similarArtistsAsync: similarArtistsAsync,
          avatarSize: metrics.artistAvatarSize,
          horizontalPadding: metrics.horizontalPadding,
          zoneGap: metrics.zoneGap,
        )
      else
        HomeYourArtists(
          artistsAsync,
          avatarSize: metrics.artistAvatarSize,
          horizontalPadding: metrics.horizontalPadding,
        ),
      HomeLikedAlbums(
        albumsAsync,
        cardWidth: metrics.cardWidth,
        horizontalPadding: metrics.horizontalPadding,
        useGrid: metrics.useLikedAlbumsGrid,
        gridColumns: 3,
        gridMaxItems: 6,
        gridSpacing: metrics.albumGridSpacing,
      ),
    ];
  }

  List<Widget> _buildDiscoverZone({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<HomeSection> sections,
    required AsyncValue<List<AlbumDetailed>> newReleasesAsync,
    required AsyncValue<List<UpNextsDetails>> discoverAsync,
    required AsyncValue<List<ArtistDetailed>> similarArtistsAsync,
    required bool showHero,
    required bool showSimilarArtists,
  }) {
    final hasHero =
        showHero && sections.isNotEmpty && sections.first.contents.isNotEmpty;

    // Explore chips are always present when online; zone is never fully empty.
    return [
      HomeZoneHeader(title: l10n.discoverZone, metrics: metrics),
      if (hasHero)
        HomeSectionRow(
          section: sections[0],
          isFirst: true,
          metrics: metrics,
          onShowAll: _browseCallback(context, sections[0]),
        ),
      HomeExplore(horizontalPadding: metrics.horizontalPadding),
      HomeNewReleases(
        newReleasesAsync,
        cardWidth: metrics.cardWidth,
        horizontalPadding: metrics.horizontalPadding,
      ),
      HomeDiscover(
        discoverAsync,
        cardWidth: metrics.cardWidth,
        horizontalPadding: metrics.horizontalPadding,
      ),
      if (showSimilarArtists)
        HomeSimilarArtists(
          similarArtistsAsync,
          avatarSize: metrics.artistAvatarSize,
          horizontalPadding: metrics.horizontalPadding,
        ),
    ];
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

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour >= 5 && hour < 12) {
      return l10n.goodMorning;
    } else if (hour >= 12 && hour < 18) {
      return l10n.goodAfternoon;
    } else {
      return l10n.goodEvening;
    }
  }

  Future<void> _refreshHome(WidgetRef ref) async {
    ref.invalidate(homeBaseResultProvider);
    ref.invalidate(homeEditorialSectionsProvider);
    await ref.read(homeBaseResultProvider.future);
  }

  void _invalidateHome(WidgetRef ref) {
    ref.invalidate(homeBaseResultProvider);
    ref.invalidate(homeEditorialSectionsProvider);
    ref.invalidate(recentHistoryProvider);
    ref.invalidate(homeCombinedPlaylistsProvider);
    ref.invalidate(homeRandomPlaylistsProvider);
    ref.invalidate(homeRandomArtistsProvider);
    ref.invalidate(homeRandomAlbumsProvider);
    ref.invalidate(homeNewReleasesProvider);
    ref.invalidate(homeRandomNewReleasesProvider);
    ref.invalidate(homeDiscoverProvider);
    ref.invalidate(homeSimilarArtistsProvider);
  }

  Future<void> _refreshOffline(WidgetRef ref) async {
    ref.invalidate(recentHistoryProvider);
    ref.invalidate(homeCombinedPlaylistsProvider);
    ref.invalidate(homeRandomPlaylistsProvider);
    ref.invalidate(homeRandomArtistsProvider);
    ref.invalidate(homeRandomAlbumsProvider);
  }
}

class _OfflineBanner extends StatelessWidget {
  final HomeLayoutMetrics metrics;

  const _OfflineBanner({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.horizontalPadding,
        vertical: 8,
      ),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              Icon(
                LucideIcons.wifiOff,
                color: Theme.of(context).colorScheme.primary,
              ),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.offlineModeActiveMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
