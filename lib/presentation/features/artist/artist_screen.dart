import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/theme/player_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/library_models.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/play_album_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/entity_shimmer.dart';
import '../../shared/widgets/artist_card.dart';
import '../../shared/widgets/entity_wide_body.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/release_card.dart';
import '../../shared/widgets/video_card.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import 'discography_kind.dart';
import 'latest_release.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/hover_carousel_arrows.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/detail_actions_bar.dart';
import '../../shared/widgets/entity_banner_header.dart';
import '../../shared/widgets/detail_affinity_button.dart';
import 'providers/artist_provider.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';

class ArtistScreen extends ConsumerWidget {
  final String artistId;

  const ArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        if (isCompactShell(size)) {
          return _ArtistMobileLayout(
            artistId: artistId,
            contentWidth: constraints.maxWidth,
          );
        } else if (size.width < kExpandedBreakpoint) {
          return _ArtistTabletLayout(
            artistId: artistId,
            contentWidth: constraints.maxWidth,
          );
        } else {
          return _ArtistWideLayout(
            artistId: artistId,
            contentWidth: constraints.maxWidth,
          );
        }
      },
    );
  }
}

class _ArtistMobileLayout extends ConsumerWidget {
  final String artistId;
  final double contentWidth;

  const _ArtistMobileLayout({
    required this.artistId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));

    return artistAsync.when(
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.artist,
          contentWidth: contentWidth,
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
      ),
      data: (artist) =>
          _ArtistContent(artist: artist, contentWidth: contentWidth),
    );
  }
}

class _ArtistTabletLayout extends ConsumerWidget {
  final String artistId;
  final double contentWidth;

  const _ArtistTabletLayout({
    required this.artistId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));

    return artistAsync.when(
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.artist,
          contentWidth: contentWidth,
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
      ),
      data: (artist) => _ArtistContent(
        artist: artist,
        isTablet: true,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _ArtistWideLayout extends ConsumerWidget {
  final String artistId;
  final double contentWidth;

  const _ArtistWideLayout({required this.artistId, required this.contentWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));

    return artistAsync.when(
      loading: () => Scaffold(
        body: EntityShimmer(
          kind: EntityShimmerKind.artist,
          contentWidth: contentWidth,
        ),
      ),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
      ),
      data: (artist) => _ArtistContent(
        artist: artist,
        isWide: true,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _ArtistContent extends ConsumerStatefulWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;

  const _ArtistContent({
    required this.artist,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_ArtistContent> createState() => _ArtistContentState();
}

class _ArtistContentState extends ConsumerState<_ArtistContent> {
  late final ScrollController _scrollController;
  late final ScrollController _albumsScrollController;
  late final ScrollController _singlesScrollController;
  late final ScrollController _videosScrollController;
  late final ScrollController _featuredOnScrollController;
  late final ScrollController _similarArtistsScrollController;
  double _scrollProgress = 0.0;
  ArtistDiscographyKind _discography = ArtistDiscographyKind.albums;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _albumsScrollController = ScrollController();
    _singlesScrollController = ScrollController();
    _videosScrollController = ScrollController();
    _featuredOnScrollController = ScrollController();
    _similarArtistsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _albumsScrollController.dispose();
    _singlesScrollController.dispose();
    _videosScrollController.dispose();
    _featuredOnScrollController.dispose();
    _similarArtistsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double expandedHeight = _artistHeaderHeight(
      tall: widget.isTablet || widget.isWide,
      wide: widget.isWide,
    );
    final double collapsedHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;
    final double delta = expandedHeight - collapsedHeight;
    final double progress = (_scrollController.offset / delta).clamp(0.0, 1.0);
    if (progress != _scrollProgress) {
      setState(() {
        _scrollProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final l10n = AppLocalizations.of(context)!;

    // Filter out the current artist and any duplicate artist IDs to prevent Hero tag collisions
    final uniqueSimilarArtists = () {
      final seen = <String>{artist.artistId};
      return artist.similarArtists.where((a) => seen.add(a.artistId)).toList();
    }();

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _ArtistSliverAppBar(
            artist: artist,
            isTablet: widget.isTablet,
            isWide: widget.isWide,
            contentWidth: widget.contentWidth,
            scrollProgress: _scrollProgress,
            actions: widget.isTablet || widget.isWide
                ? _ArtistActions(artist: artist)
                : null,
          ),
          SliverPadding(
            padding: entityBodyPadding(
              widget.contentWidth,
              shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isTablet && !widget.isWide)
                    _ArtistActions(artist: artist),
                  if (artist.description != null &&
                      artist.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ExpandableText(text: artist.description!),
                  ],
                  const SizedBox(height: 24),
                  if (artist.topSongs.isNotEmpty)
                    _ArtistTopSongsSection(
                      songs: artist.topSongs,
                      artistId: artist.artistId,
                      artistName: artist.name,
                    ),
                  ..._latestBlock(l10n, latestReleaseAlbum(artist.topAlbums)),
                  ..._discographySection(context, artist, l10n),
                  ..._similarArtistsShelf(
                    context,
                    artist,
                    uniqueSimilarArtists,
                  ),
                  ..._featuredShelf(context, artist),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _latestBlock(AppLocalizations l10n, AlbumDetailed? latest) {
    if (latest == null) return const [];
    return [
      _SectionHeader(title: l10n.latestRelease),
      const SizedBox(height: 8),
      _LatestReleaseCard(album: latest),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _discographySection(
    BuildContext context,
    ArtistFull artist,
    AppLocalizations l10n,
  ) {
    final kinds = artistDiscographyKinds(
      hasAlbums: artist.topAlbums.isNotEmpty,
      hasSingles: artist.topSingles.isNotEmpty,
      hasVideos: artist.topVideos.isNotEmpty,
    );
    final selected = resolveDiscographyKind(kinds, _discography);
    if (selected == null) return const [];
    return [
      _SectionHeader(
        title: l10n.discography,
        onShowAll: () => _openDiscography(context, artist, selected),
      ),
      if (kinds.length > 1) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in kinds)
              ChoiceChip(
                label: Text(_discographyLabel(l10n, kind)),
                selected: kind == selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _discography = kind),
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      _discographyCarousel(artist, selected),
      const SizedBox(height: 24),
    ];
  }

  String _discographyLabel(AppLocalizations l10n, ArtistDiscographyKind kind) {
    return switch (kind) {
      ArtistDiscographyKind.albums => l10n.albums,
      ArtistDiscographyKind.singles => l10n.singles,
      ArtistDiscographyKind.videos => l10n.videos,
    };
  }

  void _openDiscography(
    BuildContext context,
    ArtistFull artist,
    ArtistDiscographyKind kind,
  ) {
    final name = Uri.encodeComponent(artist.name);
    final segment = switch (kind) {
      ArtistDiscographyKind.albums => 'albums',
      ArtistDiscographyKind.singles => 'singles',
      ArtistDiscographyKind.videos => 'videos',
    };
    context.push('/artist/${artist.artistId}/$segment?name=$name');
  }

  void _openFeatured(BuildContext context, ArtistFull artist) {
    final name = Uri.encodeComponent(artist.name);
    context.push('/artist/${artist.artistId}/featured?name=$name');
  }

  Widget _discographyCarousel(ArtistFull artist, ArtistDiscographyKind kind) {
    return switch (kind) {
      ArtistDiscographyKind.albums => _releaseCarousel(
        controller: _albumsScrollController,
        scrollAmount: 480,
        height: 220,
        itemCount: artist.topAlbums.length,
        itemBuilder: (context, index) {
          final album = artist.topAlbums[index];
          return ReleaseCard(
            albumId: album.albumId,
            name: album.name,
            artist: displayArtists(album.artists),
            thumbnailUrl: album.thumbnails.isNotEmpty
                ? album.thumbnails.last.url
                : null,
            year: album.year,
            artistId: primaryArtistId(album.artists),
            type: ReleaseType.album,
            heroTag: 'artist_album_${album.albumId}',
          );
        },
      ),
      ArtistDiscographyKind.singles => _releaseCarousel(
        controller: _singlesScrollController,
        scrollAmount: 480,
        height: 220,
        itemCount: artist.topSingles.length,
        itemBuilder: (context, index) {
          final single = artist.topSingles[index];
          return ReleaseCard(
            albumId: single.albumId,
            name: single.name,
            artist: displayArtists(single.artists),
            thumbnailUrl: single.thumbnails.isNotEmpty
                ? single.thumbnails.last.url
                : null,
            year: single.year,
            artistId: primaryArtistId(single.artists),
            type: ReleaseType.single,
            heroTag: 'artist_single_${single.albumId}',
          );
        },
      ),
      ArtistDiscographyKind.videos => _releaseCarousel(
        controller: _videosScrollController,
        scrollAmount: 600,
        height: 180,
        itemCount: artist.topVideos.length,
        itemBuilder: (context, index) {
          final video = artist.topVideos[index];
          return VideoCard(
            videoId: video.videoId,
            title: video.name,
            artist: displayArtists(video.artists),
            artists: video.artists,
            thumbnailUrl: video.thumbnails.isNotEmpty
                ? video.thumbnails.last.url
                : null,
            artistId: primaryArtistId(video.artists),
            isExplicit: video.isExplicit,
            isPlayable: video.isPlayable,
          );
        },
      ),
    };
  }

  Widget _releaseCarousel({
    required ScrollController controller,
    required double scrollAmount,
    required double height,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    return SizedBox(
      height: height,
      child: HoverCarouselArrows(
        controller: controller,
        scrollAmount: scrollAmount,
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 16),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }

  List<Widget> _featuredShelf(BuildContext context, ArtistFull artist) {
    final playlists = artist.featuredOn;
    if (playlists.isEmpty) return const [];
    final l10n = AppLocalizations.of(context)!;
    return [
      _SectionHeader(
        title: l10n.featuredOn,
        onShowAll: () => _openFeatured(context, artist),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 220,
        child: HoverCarouselArrows(
          controller: _featuredOnScrollController,
          scrollAmount: 480.0,
          child: ListView.separated(
            controller: _featuredOnScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return PlaylistCard(
                playlistId: playlist.playlistId,
                name: playlist.name,
                artist: displayArtists(playlist.artists),
                thumbnailUrl: playlist.thumbnails.isNotEmpty
                    ? playlist.thumbnails.last.url
                    : null,
                heroTag: 'artist_featured_playlist_${playlist.playlistId}',
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _similarArtistsShelf(
    BuildContext context,
    ArtistFull artist,
    List<ArtistDetailed> similar,
  ) {
    if (similar.isEmpty) return const [];
    final l10n = AppLocalizations.of(context)!;
    return [
      _SectionHeader(title: l10n.similarArtists),
      const SizedBox(height: 8),
      SizedBox(
        height: 180,
        child: HoverCarouselArrows(
          controller: _similarArtistsScrollController,
          scrollAmount: 360.0,
          child: ListView.separated(
            controller: _similarArtistsScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 16),
            itemCount: similar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = similar[index];
              return ArtistCard(
                artistId: item.artistId,
                name: item.name,
                thumbnailUrl: item.thumbnails.isNotEmpty
                    ? item.thumbnails.last.url
                    : null,
                monthlyListeners: item.monthlyListeners,
                heroTag:
                    'similar_artists_${item.artistId}_on_${artist.artistId}',
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }
}

class _ArtistTopSongsSection extends StatelessWidget {
  final List<SongDetailed> songs;
  final String artistId;
  final String artistName;

  const _ArtistTopSongsSection({
    required this.songs,
    required this.artistId,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displaySongs = songs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.popular,
          onShowAll: () {
            final name = Uri.encodeComponent(artistName);
            context.push('/artist/$artistId/songs?name=$name');
          },
        ),
        const SizedBox(height: 8),
        ...displaySongs.asMap().entries.map(
          (entry) => SongTile(
            index: entry.key + 1,
            videoId: entry.value.videoId,
            title: entry.value.name,
            artist: displayArtists(entry.value.artists),
            artists: entry.value.artists,
            thumbnailUrl: entry.value.thumbnails.isNotEmpty
                ? entry.value.thumbnails.last.url
                : null,
            duration: entry.value.duration,
            isVideo: entry.value.type == 'VIDEO',
            albumName: entry.value.album?.name,
            artistId: primaryArtistId(entry.value.artists),
            albumId: entry.value.album?.albumId,
            trailingActions: [
              if (statFigure(entry.value.playCount) case final plays?)
                Text(
                  plays,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            isExplicit: entry.value.isExplicit,
            isPlayable: entry.value.isPlayable,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ArtistSliverAppBar extends StatelessWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;
  final double scrollProgress;
  final Widget? actions;

  const _ArtistSliverAppBar({
    required this.artist,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );

    final thumbnailUrl = artist.thumbnails.isNotEmpty
        ? artist.thumbnails.last.url
        : null;

    return SliverAppBar(
      expandedHeight: _artistHeaderHeight(
        tall: isTablet || isWide,
        wide: isWide,
      ),
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          artist.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          GlassAppBarBackground(opacity: scrollProgress),
          FlexibleSpaceBar(
            background: _buildHeaderBackground(context, thumbnailUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context, String? thumbnailUrl) {
    final colors = PlayerColors.of(context);

    return EntityBannerHeader(
      layout: EntityBannerLayout.photo,
      title: artist.name,
      meta: _ArtistStatRow(
        artist: artist,
        valueColor: colors.titleSecondary,
        labelColor: colors.labelMuted,
      ),
      imageUrl: thumbnailUrl,
      placeholderIcon: LucideIcons.user,
      scrollProgress: scrollProgress,
      wide: isWide,
      contentWidth: contentWidth,
      actions: actions,
    );
  }
}

class _ArtistActions extends ConsumerWidget {
  final ArtistFull artist;

  const _ArtistActions({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasSongs = playableSongs(artist.topSongs).isNotEmpty;
    final canShuffle =
        hasSongs || (artist.shuffleId != null && artist.shuffleId!.isNotEmpty);

    final secondary = rankDetailActions([
      DetailAction(
        id: DetailActionId.queue,
        icon: LucideIcons.listMusic,
        label: l10n.addToQueue,
        tooltip: l10n.addToQueue,
        onPressed: hasSongs ? () => _addToQueue(context, ref, artist) : null,
      ),
      DetailAction(
        id: DetailActionId.save,
        icon: LucideIcons.userPlus,
        label: l10n.follow,
        tooltip: l10n.follow,
        buildControl: (context, compact) =>
            _FollowButton(artist: artist, iconOnly: compact),
      ),
    ]);

    return DetailActionsBar(
      secondary: secondary,
      onPlay: hasSongs ? () => _playSequential(context, ref, artist) : null,
      playLabel: l10n.playTopSongs,
      onShuffle: canShuffle ? () => _shufflePlay(context, ref, artist) : null,
      shuffleLabel: l10n.shuffle,
      alwaysShowOverflow: true,
      onOverflow: () {
        ContextMenuSheet.showForArtist(
          context,
          artistId: artist.artistId,
          name: artist.name,
          thumbnailUrl: artist.thumbnails.isNotEmpty
              ? artist.thumbnails.last.url
              : null,
          monthlyListeners: artist.monthlyListeners,
          omitActionIds: {
            DetailActionId.play,
            DetailActionId.shuffle,
            DetailActionId.queue,
            DetailActionId.save,
          },
        );
      },
    );
  }

  Future<void> _addToQueue(
    BuildContext context,
    WidgetRef ref,
    ArtistFull artist,
  ) async {
    if (artist.topSongs.isEmpty) return;
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playAlbumUseCaseProvider);
    try {
      final songs = await _resolveAllTopSongs(ref, artist);
      final items = await useCase.execute(songs, playIndex: -1);
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(AppLocalizations.of(context)!.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add to queue: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToAddToQueue,
              kind: FeedbackKind.error,
            );
      }
    }
  }

  Future<void> _playSequential(
    BuildContext context,
    WidgetRef ref,
    ArtistFull artist,
  ) async {
    if (artist.topSongs.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    ref
        .read(actionFeedbackProvider.notifier)
        .report(l10n.playingArtist(artist.name));
    final player = ref.read(playerStateProvider.notifier);
    try {
      final songs = await _resolveAllTopSongs(ref, artist);
      await player.playAlbum(songs, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to play artist: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToPlay, kind: FeedbackKind.error);
      }
    }
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    ArtistFull artist,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    ref
        .read(actionFeedbackProvider.notifier)
        .report(l10n.shufflingArtist(artist.name));
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(startRadioUseCaseProvider);

    try {
      if (artist.shuffleId != null && artist.shuffleId!.isNotEmpty) {
        final seed = artist.topSongs.isNotEmpty
            ? artist.topSongs.first.videoId
            : '';
        final result = await useCase.execute(
          seed,
          playlistId: artist.shuffleId,
          radio: false,
          shuffle: true,
        );
        await player.playNow([result.firstItem]);
        if (result.remaining.isNotEmpty) {
          player.addAllToQueue(useCase.toPendingItems(result.remaining));
        }
        return;
      }

      if (artist.topSongs.isEmpty) return;
      final songs = await _resolveAllTopSongs(ref, artist);
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      await player.playAlbum(shuffled, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to play artist: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.failedToPlay, kind: FeedbackKind.error);
      }
    }
  }

  /// Loads the full artist songs list, falling back to the preview
  /// [ArtistFull.topSongs] if the fetch fails.
  Future<List<SongDetailed>> _resolveAllTopSongs(
    WidgetRef ref,
    ArtistFull artist,
  ) async {
    try {
      final songs = await ref.read(artistSongsProvider(artist.artistId).future);
      if (songs.isNotEmpty) return songs;
    } catch (_) {}
    return artist.topSongs;
  }
}

class _FollowButton extends ConsumerWidget {
  final ArtistFull artist;
  final bool iconOnly;

  const _FollowButton({required this.artist, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final followedAsync = ref.watch(followedArtistProvider(artist.artistId));
    return followedAsync.when(
      loading: () => DetailAffinityButton(
        iconOnly: iconOnly,
        isActive: false,
        enabled: false,
        idleIcon: DetailAffinityButton.followIdle,
        activeIcon: DetailAffinityButton.followActive,
        idleLabel: l10n.follow,
        activeLabel: l10n.following,
        activeColor: DetailAffinityButton.brandColor(
          Theme.of(context).colorScheme,
        ),
        onPressed: null,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (followed) {
        final isFollowing = followed != null;
        return DetailAffinityButton(
          iconOnly: iconOnly,
          isActive: isFollowing,
          idleIcon: DetailAffinityButton.followIdle,
          activeIcon: DetailAffinityButton.followActive,
          idleLabel: l10n.follow,
          activeLabel: l10n.following,
          activeColor: DetailAffinityButton.brandColor(
            Theme.of(context).colorScheme,
          ),
          onPressed: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleFollowedArtist(
                  FollowedArtistModel(
                    artistId: artist.artistId,
                    name: artist.name,
                    thumbnailUrl: artist.thumbnails.isNotEmpty
                        ? artist.thumbnails.last.url
                        : null,
                    addedAt: DateTime.now(),
                  ),
                );
          },
        );
      },
    );
  }
}

double _artistHeaderHeight({required bool tall, required bool wide}) =>
    EntityBannerHeader.expandedHeight(
      wide: wide,
      hasActions: tall,
      layout: EntityBannerLayout.photo,
    );

class _ArtistStatRow extends StatelessWidget {
  final ArtistFull artist;
  final Color valueColor;
  final Color labelColor;

  const _ArtistStatRow({
    required this.artist,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stats = <({String value, String label})>[
      if (statFigure(artist.subscriberCount) case final value?)
        (value: value, label: l10n.subscribers),
      if (statFigure(artist.monthlyListeners) case final value?)
        (value: value, label: l10n.monthlyListeners),
      if (statFigure(artist.totalViews) case final value?)
        (value: value, label: l10n.totalViews),
    ];
    if (stats.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                Text(
                  stats[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LatestReleaseCard extends StatelessWidget {
  final AlbumDetailed album;

  const _LatestReleaseCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final thumbnailUrl = album.thumbnails.isNotEmpty
        ? album.thumbnails.last.url
        : null;
    final subtitle = [
      if (album.year != null) '${album.year}',
      displayArtists(album.artists),
    ].where((part) => part.isNotEmpty).join(' · ');

    return Material(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusMedia),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/album/${album.albumId}'),
        onLongPress: () => ContextMenuSheet.showForAlbum(
          context,
          albumId: album.albumId,
          name: album.name,
          artist: displayArtists(album.artists),
          artistId: primaryArtistId(album.artists),
          thumbnailUrl: thumbnailUrl,
          year: album.year,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ThumbnailWidget(
                imageUrl: thumbnailUrl,
                size: 72,
                shape: ThumbnailShape.rounded,
                borderRadius: SonoraPulseTokens.radiusSm,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onShowAll;

  const _SectionHeader({required this.title, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
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
                    l10n.showAll,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
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
