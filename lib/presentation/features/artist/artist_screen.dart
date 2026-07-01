import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/extensions/duration_ext.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/player_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/library_models.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/play_album_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/artist_card.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/release_card.dart';
import '../../shared/widgets/video_card.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/hover_carousel_arrows.dart';
import '../../providers/download_provider.dart';
import 'providers/artist_provider.dart';

class ArtistScreen extends ConsumerWidget {
  final String artistId;
  final String? heroTag;

  const ArtistScreen({super.key, required this.artistId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _ArtistMobileLayout(artistId: artistId, heroTag: heroTag);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _ArtistTabletLayout(artistId: artistId, heroTag: heroTag);
        } else {
          return _ArtistWideLayout(artistId: artistId, heroTag: heroTag);
        }
      },
    );
  }
}

class _ArtistMobileLayout extends ConsumerWidget {
  final String artistId;
  final String? heroTag;

  const _ArtistMobileLayout({required this.artistId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));

    return artistAsync.when(
      loading: () => const Scaffold(body: _ArtistShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadArtist,
              onRetry: () => ref.invalidate(artistProvider(artistId)),
            ),
          ),
      data: (artist) => _ArtistContent(artist: artist, heroTag: heroTag),
    );
  }
}

class _ArtistTabletLayout extends ConsumerWidget {
  final String artistId;
  final String? heroTag;

  const _ArtistTabletLayout({required this.artistId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));

    return artistAsync.when(
      loading: () => const Scaffold(body: _ArtistShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadArtist,
              onRetry: () => ref.invalidate(artistProvider(artistId)),
            ),
          ),
      data:
          (artist) =>
              _ArtistContent(artist: artist, isTablet: true, heroTag: heroTag),
    );
  }
}

class _ArtistWideLayout extends ConsumerWidget {
  final String artistId;
  final String? heroTag;

  const _ArtistWideLayout({required this.artistId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));

    return artistAsync.when(
      loading: () => const Scaffold(body: _ArtistShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadArtist,
              onRetry: () => ref.invalidate(artistProvider(artistId)),
            ),
          ),
      data:
          (artist) =>
              _ArtistContent(artist: artist, isWide: true, heroTag: heroTag),
    );
  }
}

class _ArtistContent extends ConsumerStatefulWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;
  final String? heroTag;

  const _ArtistContent({
    required this.artist,
    this.isTablet = false,
    this.isWide = false,
    this.heroTag,
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
    final double expandedHeight =
        widget.isTablet || widget.isWide ? 360.0 : 340.0;
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
            scrollProgress: _scrollProgress,
            heroTag: widget.heroTag,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isWide ? 48 : 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    ),
                  if (artist.topAlbums.isNotEmpty) ...[
                    _SectionHeader(title: l10n.albums),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: HoverCarouselArrows(
                        controller: _albumsScrollController,
                        scrollAmount: 480.0,
                        child: ListView.separated(
                          controller: _albumsScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 16),
                          itemCount: artist.topAlbums.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final album = artist.topAlbums[index];
                            return ReleaseCard(
                              albumId: album.albumId,
                              name: album.name,
                              artist: album.artist.name,
                              thumbnailUrl:
                                  album.thumbnails.isNotEmpty
                                      ? album.thumbnails.last.url
                                      : null,
                              year: album.year,
                              artistId: album.artist.artistId,
                              type: ReleaseType.album,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (artist.topSingles.isNotEmpty) ...[
                    _SectionHeader(title: l10n.singles),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: HoverCarouselArrows(
                        controller: _singlesScrollController,
                        scrollAmount: 480.0,
                        child: ListView.separated(
                          controller: _singlesScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 16),
                          itemCount: artist.topSingles.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final single = artist.topSingles[index];
                            return ReleaseCard(
                              albumId: single.albumId,
                              name: single.name,
                              artist: single.artist.name,
                              thumbnailUrl:
                                  single.thumbnails.isNotEmpty
                                      ? single.thumbnails.last.url
                                      : null,
                              year: single.year,
                              artistId: single.artist.artistId,
                              type: ReleaseType.single,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (artist.topVideos.isNotEmpty) ...[
                    _SectionHeader(title: l10n.videos),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: HoverCarouselArrows(
                        controller: _videosScrollController,
                        scrollAmount: 600.0,
                        child: ListView.separated(
                          controller: _videosScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 16),
                          itemCount: artist.topVideos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final video = artist.topVideos[index];
                            return VideoCard(
                              videoId: video.videoId,
                              title: video.name,
                              artist: video.artist.name,
                              thumbnailUrl:
                                  video.thumbnails.isNotEmpty
                                      ? video.thumbnails.last.url
                                      : null,
                              artistId: video.artist.artistId,
                              isExplicit: video.isExplicit,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (artist.featuredOn.isNotEmpty) ...[
                    _SectionHeader(
                      title: AppLocalizations.of(context)!.featuredOn,
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
                          itemCount: artist.featuredOn.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final playlist = artist.featuredOn[index];
                            return PlaylistCard(
                              playlistId: playlist.playlistId,
                              name: playlist.name,
                              artist: playlist.artist.name,
                              thumbnailUrl:
                                  playlist.thumbnails.isNotEmpty
                                      ? playlist.thumbnails.last.url
                                      : null,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (uniqueSimilarArtists.isNotEmpty) ...[
                    _SectionHeader(
                      title: AppLocalizations.of(context)!.similarArtists,
                    ),
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
                          itemCount: uniqueSimilarArtists.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final similar = uniqueSimilarArtists[index];
                            return ArtistCard(
                              artistId: similar.artistId,
                              name: similar.name,
                              thumbnailUrl:
                                  similar.thumbnails.isNotEmpty
                                      ? similar.thumbnails.last.url
                                      : null,
                              monthlyListeners: similar.monthlyListeners,
                              heroTag:
                                  'similar_artists_${similar.artistId}_on_${artist.artistId}',
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistTopSongsSection extends ConsumerStatefulWidget {
  final List<SongDetailed> songs;
  final String artistId;

  const _ArtistTopSongsSection({required this.songs, required this.artistId});

  @override
  ConsumerState<_ArtistTopSongsSection> createState() =>
      _ArtistTopSongsSectionState();
}

class _ArtistTopSongsSectionState
    extends ConsumerState<_ArtistTopSongsSection> {
  bool _expanded = false;
  bool _loading = false;
  List<SongDetailed>? _allSongs;

  @override
  Widget build(BuildContext context) {
    final displaySongs =
        _expanded && _allSongs != null
            ? _allSongs!.take(10).toList()
            : widget.songs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: AppLocalizations.of(context)!.popular),
        const SizedBox(height: 8),
        ...displaySongs.asMap().entries.map(
          (entry) => _NumberedSongTile(index: entry.key + 1, song: entry.value),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child:
                _expanded
                    ? TextButton.icon(
                      onPressed: () => setState(() => _expanded = false),
                      icon: const Icon(LucideIcons.chevronUp),
                      label: Text(AppLocalizations.of(context)!.showLess),
                    )
                    : TextButton.icon(
                      onPressed: () {
                        if (_allSongs != null) {
                          setState(() => _expanded = true);
                        } else {
                          _fetchAllSongs();
                        }
                      },
                      icon: const Icon(LucideIcons.chevronDown),
                      label: Text(AppLocalizations.of(context)!.showMore),
                    ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _fetchAllSongs() async {
    setState(() => _loading = true);
    try {
      final songs = await ref
          .read(musicRepositoryProvider)
          .getArtistSongs(widget.artistId);
      if (!mounted) return;
      setState(() {
        _allSongs = songs;
        _expanded = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failedToLoadSongs(e.toString()),
          ),
        ),
      );
    }
  }
}

class _NumberedSongTile extends ConsumerWidget {
  final int index;
  final SongDetailed song;

  const _NumberedSongTile({required this.index, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(song.videoId);

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              ThumbnailWidget(
                imageUrl:
                    song.thumbnails.isNotEmpty
                        ? song.thumbnails.last.url
                        : null,
                size: 48,
                shape: ThumbnailShape.rounded,
              ),
              if (isDownloaded)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.checkCircle,
                      size: 10,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      title: Text(song.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.isExplicit) ...[
            const ExplicitBadge(),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              [
                song.artist.name,
                if (song.album?.name != null) song.album!.name,
                if (song.playCount != null && song.playCount!.isNotEmpty)
                  song.playCount,
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      trailing:
          song.duration != null
              ? Text(
                Duration(seconds: song.duration!).format(),
                style: textTheme.bodySmall,
              )
              : null,
      onTap:
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                song.videoId,
                isVideo: song.type == 'VIDEO',
                isExplicit: song.isExplicit,
              ),
      onLongPress:
          () => ContextMenuSheet.showForSong(
            context,
            videoId: song.videoId,
            title: song.name,
            artist: song.artist.name,
            thumbnailUrl:
                song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
            duration: song.duration,
            isVideo: song.type == 'VIDEO',
            albumName: song.album?.name,
            artistId: song.artist.artistId,
            albumId: song.album?.albumId,
            playCount: song.playCount,
            isExplicit: song.isExplicit,
          ),
    );
  }
}

class _ArtistSliverAppBar extends StatelessWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;
  final double scrollProgress;
  final String? heroTag;

  const _ArtistSliverAppBar({
    required this.artist,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        artist.thumbnails.isNotEmpty ? artist.thumbnails.last.url : null;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 340,
      pinned: true,
      // Back button and actions always white — readable on any artwork.
      iconTheme: const IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          artist.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeaderBackground(context, thumbnailUrl),
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context, String? thumbnailUrl) {
    final isTabletOrWide = isTablet || isWide;
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);

    if (!isTabletOrWide) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Opacity(
                  opacity: 0.4,
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          _artworkTopScrim(context),
          Positioned(
            top: 56 + MediaQuery.of(context).padding.top,
            bottom: 12,
            left: 24,
            right: 24,
            child: Opacity(
              opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (thumbnailUrl != null)
                    Hero(
                      tag: heroTag ?? 'artist_art_${artist.artistId}',
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget:
                                (_, _, _) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    LucideIcons.user,
                                    size: 60,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        LucideIcons.user,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    artist.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ([
                    artist.subscriberCount,
                    artist.monthlyListeners,
                    artist.totalViews,
                  ].any((e) => e != null && e.isNotEmpty)) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (artist.subscriberCount != null &&
                            artist.subscriberCount!.isNotEmpty)
                          '${artist.subscriberCount} ${AppLocalizations.of(context)!.subscribers}',
                        if (artist.monthlyListeners != null &&
                            artist.monthlyListeners!.isNotEmpty)
                          artist.monthlyListeners,
                        if (artist.totalViews != null &&
                            artist.totalViews!.isNotEmpty)
                          artist.totalViews,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.labelMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrl != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Opacity(
                opacity: 0.35,
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(color: theme.colorScheme.surfaceContainerHighest),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                theme.colorScheme.surface.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
        _artworkTopScrim(context),
        Positioned(
          top: 80 + MediaQuery.of(context).padding.top,
          bottom: 24,
          left: isWide ? 40 : 24,
          right: isWide ? 40 : 24,
          child: Opacity(
            opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (thumbnailUrl != null)
                  Hero(
                    tag: heroTag ?? 'artist_art_${artist.artistId}',
                    child: Container(
                      width: isWide ? 190 : 150,
                      height: isWide ? 190 : 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget:
                              (_, _, _) => Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: isWide ? 190 : 150,
                    height: isWide ? 190 : 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      LucideIcons.user,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.badgeCheck,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ARTIST',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                              color: colors.labelMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        artist.name,
                        style: (isWide
                                ? theme.textTheme.headlineLarge
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.titlePrimary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      if ([
                        artist.subscriberCount,
                        artist.monthlyListeners,
                        artist.totalViews,
                      ].any((e) => e != null && e.isNotEmpty))
                        Text(
                          [
                            if (artist.subscriberCount != null &&
                                artist.subscriberCount!.isNotEmpty)
                              '${artist.subscriberCount} ${AppLocalizations.of(context)!.subscribers}',
                            if (artist.monthlyListeners != null &&
                                artist.monthlyListeners!.isNotEmpty)
                              artist.monthlyListeners,
                            if (artist.totalViews != null &&
                                artist.totalViews!.isNotEmpty)
                              artist.totalViews,
                          ].join(' · '),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.titleSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistActions extends ConsumerWidget {
  final ArtistFull artist;

  const _ArtistActions({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSongs = artist.topSongs.isNotEmpty;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kCompactBreakpoint;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FollowButton(artist: artist, iconOnly: true),
                IconButton(
                  icon: const Icon(LucideIcons.shuffle),
                  onPressed:
                      hasSongs
                          ? () => _shufflePlay(context, ref, artist)
                          : null,
                  tooltip: AppLocalizations.of(context)!.shuffle,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.share2),
                  tooltip: AppLocalizations.of(context)!.share,
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'https://music.youtube.com/channel/${artist.artistId}',
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical),
                  onPressed: () {
                    ContextMenuSheet.showForArtist(
                      context,
                      artistId: artist.artistId,
                      name: artist.name,
                      thumbnailUrl:
                          artist.thumbnails.isNotEmpty
                              ? artist.thumbnails.last.url
                              : null,
                      monthlyListeners: artist.monthlyListeners,
                    );
                  },
                ),
              ],
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: FilledButton(
                onPressed:
                    hasSongs
                        ? () => _playSequential(context, ref, artist)
                        : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(LucideIcons.play, size: 28),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed:
              hasSongs ? () => _playSequential(context, ref, artist) : null,
          icon: const Icon(LucideIcons.play),
          label: Text(AppLocalizations.of(context)!.playTopSongs),
        ),
        FilledButton.icon(
          onPressed: hasSongs ? () => _shufflePlay(context, ref, artist) : null,
          icon: const Icon(LucideIcons.shuffle),
          label: Text(AppLocalizations.of(context)!.shuffle),
        ),
        _FollowButton(artist: artist),
        _ArtistRadioButton(artist: artist),
        IconButton(
          icon: const Icon(LucideIcons.share2),
          tooltip: AppLocalizations.of(context)!.share,
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text: 'https://music.youtube.com/channel/${artist.artistId}',
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _playSequential(
    BuildContext context,
    WidgetRef ref,
    ArtistFull artist,
  ) async {
    if (artist.topSongs.isEmpty) return;
    ref.read(actionFeedbackProvider.notifier).report('Playing ${artist.name}…');
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playAlbumUseCaseProvider);
    try {
      final items = await useCase.execute(artist.topSongs);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPlay(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    ArtistFull artist,
  ) async {
    if (artist.topSongs.isEmpty) return;
    ref
        .read(actionFeedbackProvider.notifier)
        .report('Shuffling ${artist.name}…');
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playAlbumUseCaseProvider);
    final shuffled = List<SongDetailed>.from(artist.topSongs)..shuffle();
    try {
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPlay(e.toString()),
            ),
          ),
        );
      }
    }
  }
}

class _FollowButton extends ConsumerWidget {
  final ArtistFull artist;
  final bool iconOnly;

  const _FollowButton({required this.artist, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedAsync = ref.watch(followedArtistProvider(artist.artistId));
    return followedAsync.when(
      loading:
          () =>
              iconOnly
                  ? const IconButton(
                    onPressed: null,
                    icon: Icon(LucideIcons.userPlus),
                  )
                  : FilledButton.tonal(
                    onPressed: null,
                    child: Text(AppLocalizations.of(context)!.follow),
                  ),
      error: (e, _) => const SizedBox.shrink(),
      data: (followed) {
        final isFollowing = followed != null;
        if (iconOnly) {
          return IconButton(
            onPressed: () async {
              await ref
                  .read(libraryNotifierProvider.notifier)
                  .toggleFollowedArtist(
                    FollowedArtistModel(
                      artistId: artist.artistId,
                      name: artist.name,
                      thumbnailUrl:
                          artist.thumbnails.isNotEmpty
                              ? artist.thumbnails.last.url
                              : null,
                      addedAt: DateTime.now(),
                    ),
                  );
            },
            icon: Icon(
              isFollowing ? LucideIcons.userCheck : LucideIcons.userPlus,
            ),
            color: isFollowing ? Theme.of(context).colorScheme.primary : null,
            tooltip:
                isFollowing
                    ? AppLocalizations.of(context)!.following
                    : AppLocalizations.of(context)!.follow,
          );
        }
        return FilledButton.tonal(
          onPressed: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleFollowedArtist(
                  FollowedArtistModel(
                    artistId: artist.artistId,
                    name: artist.name,
                    thumbnailUrl:
                        artist.thumbnails.isNotEmpty
                            ? artist.thumbnails.last.url
                            : null,
                    addedAt: DateTime.now(),
                  ),
                );
          },
          child: Text(
            isFollowing
                ? AppLocalizations.of(context)!.following
                : AppLocalizations.of(context)!.follow,
          ),
        );
      },
    );
  }
}

class _ArtistRadioButton extends ConsumerWidget {
  final ArtistFull artist;

  const _ArtistRadioButton({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSongs = artist.topSongs.isNotEmpty;

    return FilledButton.icon(
      onPressed:
          hasSongs
              ? () =>
                  _startArtistRadio(context, ref, artist.topSongs.first.videoId)
              : null,
      icon: const Icon(LucideIcons.radio),
      label: Text(AppLocalizations.of(context)!.artistRadio),
    );
  }

  Future<void> _startArtistRadio(
    BuildContext context,
    WidgetRef ref,
    String videoId,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(startRadioUseCaseProvider);

    try {
      final result = await useCase.execute(videoId);
      await player.playNow([result.firstItem]);

      if (result.remaining.isNotEmpty) {
        final pendingItems = useCase.toPendingItems(result.remaining);
        player.addAllToQueue(pendingItems);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToStartArtistRadio(e.toString()),
            ),
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ArtistShimmer extends StatelessWidget {
  const _ArtistShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: ShimmerLoading(variant: ShimmerVariant.tile),
                    ),
                    SizedBox(width: 12),
                    const Expanded(
                      child: ShimmerLoading(variant: ShimmerVariant.tile),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ...List.generate(
                  3,
                  (_) => ShimmerLoading(variant: ShimmerVariant.tile),
                ),
                const SizedBox(height: 16),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ShimmerLoading(variant: ShimmerVariant.carousel),
                const SizedBox(height: 16),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ShimmerLoading(variant: ShimmerVariant.carousel),
                const SizedBox(height: 16),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ShimmerLoading(variant: ShimmerVariant.carousel),
                const SizedBox(height: 16),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ...List.generate(
                  2,
                  (_) => ShimmerLoading(variant: ShimmerVariant.tile),
                ),
                const SizedBox(height: 16),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ShimmerLoading(variant: ShimmerVariant.carousel),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Top dark scrim for artwork headers — reads colours from [PlayerColors].
Widget _artworkTopScrim(BuildContext context) {
  final pc = PlayerColors.of(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.20, 0.32],
        colors: [pc.topScrimStart, pc.topScrimMid, Colors.transparent],
      ),
    ),
  );
}
