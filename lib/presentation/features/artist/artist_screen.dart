import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/models/library_models.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/play_album_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/artist_card.dart';
import '../../shared/widgets/playlist_card.dart';
import 'providers/artist_provider.dart';

class ArtistScreen extends ConsumerWidget {
  final String artistId;

  const ArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _ArtistMobileLayout(artistId: artistId);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _ArtistTabletLayout(artistId: artistId);
        } else {
          return _ArtistWideLayout(artistId: artistId);
        }
      },
    );
  }
}

class _ArtistMobileLayout extends ConsumerWidget {
  final String artistId;

  const _ArtistMobileLayout({required this.artistId});

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
      data: (artist) => _ArtistContent(artist: artist),
    );
  }
}

class _ArtistTabletLayout extends ConsumerWidget {
  final String artistId;

  const _ArtistTabletLayout({required this.artistId});

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
      data: (artist) => _ArtistContent(artist: artist, isTablet: true),
    );
  }
}

class _ArtistWideLayout extends ConsumerWidget {
  final String artistId;

  const _ArtistWideLayout({required this.artistId});

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
      data: (artist) => _ArtistContent(artist: artist, isWide: true),
    );
  }
}

class _ArtistContent extends ConsumerStatefulWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;

  const _ArtistContent({
    required this.artist,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_ArtistContent> createState() => _ArtistContentState();
}

class _ArtistContentState extends ConsumerState<_ArtistContent> {
  late final ScrollController _scrollController;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double expandedHeight =
        widget.isTablet || widget.isWide ? 360.0 : 280.0;
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
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _ArtistSliverAppBar(
            artist: widget.artist,
            isTablet: widget.isTablet,
            isWide: widget.isWide,
            scrollProgress: _scrollProgress,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isWide ? 48 : 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ArtistActions(artist: widget.artist),
                  if (widget.artist.description != null &&
                      widget.artist.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ExpandableText(text: widget.artist.description!),
                  ],
                  const SizedBox(height: 24),
                  if (widget.artist.topSongs.isNotEmpty)
                    _ArtistTopSongsSection(
                      songs: widget.artist.topSongs,
                      artistId: widget.artist.artistId,
                    ),
                  if (widget.artist.topAlbums.isNotEmpty) ...[
                    _SectionHeader(title: AppLocalizations.of(context)!.albums),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: widget.artist.topAlbums.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final album = widget.artist.topAlbums[index];
                          return AlbumCard(
                            albumId: album.albumId,
                            name: album.name,
                            artist: album.artist.name,
                            thumbnailUrl:
                                album.thumbnails.isNotEmpty
                                    ? album.thumbnails.last.url
                                    : null,
                            year: album.year,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.artist.topSingles.isNotEmpty) ...[
                    _SectionHeader(
                      title: AppLocalizations.of(context)!.singles,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: widget.artist.topSingles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final single = widget.artist.topSingles[index];
                          return AlbumCard(
                            albumId: single.albumId,
                            name: single.name,
                            artist: single.artist.name,
                            thumbnailUrl:
                                single.thumbnails.isNotEmpty
                                    ? single.thumbnails.last.url
                                    : null,
                            year: single.year,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.artist.topVideos.isNotEmpty) ...[
                    _SectionHeader(title: AppLocalizations.of(context)!.videos),
                    const SizedBox(height: 8),
                    ...widget.artist.topVideos.map(
                      (video) => SongTile(
                        videoId: video.videoId,
                        title: video.name,
                        artist: video.artist.name,
                        thumbnailUrl:
                            video.thumbnails.isNotEmpty
                                ? video.thumbnails.last.url
                                : null,
                        duration: video.duration,
                        isVideo: true,
                        playCount: video.viewCount,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.artist.featuredOn.isNotEmpty) ...[
                    _SectionHeader(
                      title: AppLocalizations.of(context)!.featuredOn,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: widget.artist.featuredOn.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final playlist = widget.artist.featuredOn[index];
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
                    const SizedBox(height: 24),
                  ],
                  if (widget.artist.similarArtists.isNotEmpty) ...[
                    _SectionHeader(
                      title: AppLocalizations.of(context)!.similarArtists,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: widget.artist.similarArtists.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final similar = widget.artist.similarArtists[index];
                          return ArtistCard(
                            artistId: similar.artistId,
                            name: similar.name,
                            thumbnailUrl:
                                similar.thumbnails.isNotEmpty
                                    ? similar.thumbnails.last.url
                                    : null,
                            monthlyListeners: similar.monthlyListeners,
                          );
                        },
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
        _SectionHeader(title: AppLocalizations.of(context)!.topSongs),
        const SizedBox(height: 8),
        ...displaySongs.map(
          (song) => SongTile(
            videoId: song.videoId,
            title: song.name,
            artist: song.artist.name,
            thumbnailUrl:
                song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
            duration: song.duration,
            albumName: song.album?.name,
            albumId: song.album?.albumId,
            artistId: song.artist.artistId,
            playCount: song.playCount,
          ),
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

class _ArtistSliverAppBar extends StatelessWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;
  final double scrollProgress;

  const _ArtistSliverAppBar({
    required this.artist,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        artist.thumbnails.isNotEmpty ? artist.thumbnails.last.url : null;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 280,
      pinned: true,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          artist.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null)
              Hero(
                tag: 'artist_art_${artist.artistId}',
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, _, _) => Container(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                ),
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ([
                      artist.subscriberCount,
                      artist.monthlyListeners,
                      artist.totalViews,
                    ].any((e) => e != null && e.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistActions extends ConsumerWidget {
  final ArtistFull artist;

  const _ArtistActions({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSongs = artist.topSongs.isNotEmpty;

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

  const _FollowButton({required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedAsync = ref.watch(followedArtistProvider(artist.artistId));
    return followedAsync.when(
      loading:
          () => FilledButton.tonal(
            onPressed: null,
            child: Text(AppLocalizations.of(context)!.follow),
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (followed) {
        final isFollowing = followed != null;
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

class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            widget.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            widget.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown),
          label: Text(
            _expanded
                ? AppLocalizations.of(context)!.showLess
                : AppLocalizations.of(context)!.showMore,
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
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
