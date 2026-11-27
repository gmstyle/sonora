import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/app_lifecycle_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/glass_app_bar_background.dart';
import '../../../shared/widgets/sonora_logo.dart';
import '../../../shared/widgets/youtube_account_button.dart';
import '../providers/home_provider.dart';
import '../widgets/home_quick_row.dart';
import '../widgets/home_wrapped_entry.dart';
import '../widgets/home_section_renderer.dart';
import '../widgets/home_zone_header.dart';
import 'home_layout_metrics.dart';

class HomeFeedLayout extends ConsumerStatefulWidget {
  final HomeLayoutMetrics metrics;

  const HomeFeedLayout({super.key, required this.metrics});

  @override
  ConsumerState<HomeFeedLayout> createState() => _HomeFeedLayoutState();
}

class _HomeFeedLayoutState extends ConsumerState<HomeFeedLayout> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);

  HomeLayoutMetrics get metrics => widget.metrics;

  HomeLayoutSize get size => metrics.size;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final progress = (_scrollController.offset / 20.0).clamp(0.0, 1.0);
    if (progress == _scrollProgress.value) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final next = (_scrollController.offset / 20.0).clamp(0.0, 1.0);
        if (next != _scrollProgress.value) {
          _scrollProgress.value = next;
        }
      });
      return;
    }
    _scrollProgress.value = progress;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(homeSelectedChipParamsProvider, (previous, next) {
      if (previous == next) return;
      _scrollFeedToTop();
    });
    ref.watch(appLifecycleProvider);
    final baseResult = ref.watch(homeBaseResultProvider);
    final baseSectionsAsync = ref.watch(homeBaseSectionsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);
    final playlistsAsync = ref.watch(homeRandomPlaylistsProvider);
    final artistsAsync = ref.watch(homeRandomArtistsProvider);
    final albumsAsync = ref.watch(homeRandomAlbumsProvider);
    final newReleasesAsync = ref.watch(homeRandomNewReleasesProvider);
    final discoverAsync = ref.watch(homeDiscoverProvider);
    final similarArtistsAsync = ref.watch(homeSimilarArtistsProvider);
    final selectedChip = ref.watch(homeSelectedChipParamsProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final showChipBar =
        !isOffline &&
        (baseResult.isLoading ||
            (baseResult.asData?.value.chips.isNotEmpty ?? false));
    final chipFeed = !isOffline && selectedChip != null;
    final l10n = AppLocalizations.of(context)!;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    SliverAppBar buildAppBar({required bool trackScroll}) => _buildSliverAppBar(
      context,
      l10n,
      showChipBar: showChipBar,
      reduceEffects: reduceEffects,
      trackScroll: trackScroll,
    );

    final Widget bodyScrollView;
    if (isOffline) {
      bodyScrollView = _buildScrollableFeed(
        sliverAppBar: buildAppBar(trackScroll: true),
        bottomPadding: bottomPadding,
        onRefresh: () => _refreshOffline(ref),
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
      );
    } else {
      bodyScrollView = baseSectionsAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            buildAppBar(trackScroll: false),
            SliverToBoxAdapter(
              child: HomeShimmer(
                metrics: metrics,
                reserveChipBar: false,
                reserveAppBar: false,
              ),
            ),
          ],
        ),
        error: (_, _) => CustomScrollView(
          slivers: [
            buildAppBar(trackScroll: false),
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorRetryWidget(
                message: l10n.failedToLoadHomeFeed,
                onRetry: () => ref.invalidate(homeBaseResultProvider),
              ),
            ),
          ],
        ),
        data: (sections) => _buildScrollableFeed(
          sliverAppBar: buildAppBar(trackScroll: true),
          bottomPadding: bottomPadding,
          onRefresh: () => _refreshHome(ref),
          children: [
            if (chipFeed)
              HomeFeedShelves(metrics: metrics, chipFeed: true)
            else ...[
              ..._buildRiprendiZone(historyAsync: historyAsync),
              HomeExplore(horizontalPadding: metrics.horizontalPadding),
              ..._buildYourMusicZone(
                l10n: l10n,
                playlistsAsync: playlistsAsync,
                artistsAsync: artistsAsync,
                albumsAsync: albumsAsync,
                similarArtistsAsync: similarArtistsAsync,
                includeSimilarInMusicZone: metrics.useSideBySideArtists,
              ),
              ..._buildDiscoverZone(
                context: context,
                l10n: l10n,
                sections: sections,
                newReleasesAsync: newReleasesAsync,
                discoverAsync: discoverAsync,
                similarArtistsAsync: similarArtistsAsync,
                showHero: true,
                showSimilarArtists: !metrics.useSideBySideArtists,
              ),
              HomeFeedShelves(metrics: metrics),
            ],
          ],
        ),
      );
    }

    // Desktop escape hatch: F5 / Ctrl+R / Cmd+R (pull-to-refresh covers touch).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            _invalidateHome(ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
            _invalidateHome(ref),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _invalidateHome(ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          // MobileShell already shrinks for the IME; resizing here leaves a
          // blank band under Moment Mix when the keyboard opens.
          resizeToAvoidBottomInset: false,
          body: AmbientBackground(child: bodyScrollView),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showChipBar,
    required bool reduceEffects,
    required bool trackScroll,
  }) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: trackScroll
          ? ValueListenableBuilder<double>(
              valueListenable: _scrollProgress,
              builder: (context, progress, _) =>
                  GlassAppBarBackground(opacity: progress, blur: !reduceEffects),
            )
          : null,
      title: Row(
        spacing: 8,
        children: [
          const SonoraLogo.icon(22),
          Flexible(
            child: Text(
              _getGreeting(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
      centerTitle: false,
      bottom: showChipBar
          ? HomeChipsBar(horizontalPadding: metrics.horizontalPadding)
          : null,
      actions: [
        // Mobile only: on tablet and wide, account and settings live in the sidebar.
        if (size == HomeLayoutSize.mobile) ...[
          const YoutubeAccountIconButton(),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: l10n.settingsLabel,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ],
    );
  }

  Widget _buildScrollableFeed({
    required SliverAppBar sliverAppBar,
    required double bottomPadding,
    required Future<void> Function() onRefresh,
    required List<Widget> children,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          sliverAppBar,
          SliverPadding(
            padding: EdgeInsets.only(top: 12, bottom: bottomPadding),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }

  void _scrollFeedToTop() {
    _scrollProgress.value = 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  List<Widget> _buildRiprendiZone({required AsyncValue historyAsync}) {
    final showQuickRow =
        asyncHistoryHasContent(historyAsync) || HomeQuickRow.mixesHasContent();

    return [
      if (!metrics.useSideBySideQuickRow) HomeWrappedEntry(metrics: metrics),
      if (showQuickRow)
        HomeQuickRow(historyAsync: historyAsync, metrics: metrics),
    ];
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
    final hasArtistsBlock = includeSimilarInMusicZone
        ? (hasArtists || hasSimilar)
        : hasArtists;

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
        gridColumns: metrics.albumGridColumns,
        gridMaxItems: metrics.albumGridMaxItems,
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

    return [
      HomeZoneHeader(title: l10n.discoverZone, metrics: metrics),
      if (hasHero)
        HomeSectionRow(
          section: sections[0],
          isFirst: true,
          metrics: metrics,
          onShowAll: _browseCallback(context, sections[0]),
        ),
      if (!hasNewReleasesSection(sections, localizedTitle: l10n.newReleases))
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
      final paramsEncoded = section.browseParams != null
          ? '&params=${section.browseParams}'
          : '';
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

class _OfflineBanner extends ConsumerWidget {
  final HomeLayoutMetrics metrics;

  const _OfflineBanner({required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isManualOffline = ref.watch(settingsProvider).offlineMode;
    final message = isManualOffline
        ? l10n.offlineModeActiveMessage
        : l10n.noConnectionActiveMessage;
    final mark = isManualOffline ? colorScheme.tertiary : colorScheme.error;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.horizontalPadding,
        vertical: 8,
      ),
      child: Card(
        color: colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: mark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(message, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isManualOffline)
                    OutlinedButton(
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .setOfflineMode(false),
                      child: Text(l10n.disableOfflineMode),
                    ),
                  FilledButton.tonal(
                    onPressed: () => context.go('/downloads'),
                    child: Text(l10n.goToDownloads),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
