import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/models/library_models.dart';
import '../../providers/library_repository_provider.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/artist_card.dart';
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
              message: 'Failed to load artist',
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
              message: 'Failed to load artist',
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
              message: 'Failed to load artist',
              onRetry: () => ref.invalidate(artistProvider(artistId)),
            ),
          ),
      data: (artist) => _ArtistContent(artist: artist, isWide: true),
    );
  }
}

class _ArtistContent extends ConsumerWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;

  const _ArtistContent({
    required this.artist,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _ArtistSliverAppBar(artist: artist, isTablet: isTablet, isWide: isWide),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, isWide ? 48 : 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ArtistActions(artist: artist),
                  const SizedBox(height: 24),
                  if (artist.topSongs.isNotEmpty) ...[
                    _SectionHeader(title: 'Top Songs'),
                    const SizedBox(height: 8),
                    ...artist.topSongs
                        .take(isWide ? 10 : 5)
                        .map(
                          (song) => SongTile(
                            videoId: song.videoId,
                            title: song.name,
                            artist: song.artist.name,
                            thumbnailUrl:
                                song.thumbnails.isNotEmpty
                                    ? song.thumbnails.last.url
                                    : null,
                            duration: song.duration,
                            albumName: song.album?.name,
                          ),
                        ),
                    const SizedBox(height: 24),
                  ],
                  if (artist.topAlbums.isNotEmpty) ...[
                    _SectionHeader(title: 'Albums'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: artist.topAlbums.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final album = artist.topAlbums[index];
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
                  if (artist.topSingles.isNotEmpty) ...[
                    _SectionHeader(title: 'Singles'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: artist.topSingles.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final single = artist.topSingles[index];
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
                  if (artist.similarArtists.isNotEmpty) ...[
                    _SectionHeader(title: 'Similar Artists'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: artist.similarArtists.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final similar = artist.similarArtists[index];
                          return ArtistCard(
                            artistId: similar.artistId,
                            name: similar.name,
                            thumbnailUrl:
                                similar.thumbnails.isNotEmpty
                                    ? similar.thumbnails.last.url
                                    : null,
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

class _ArtistSliverAppBar extends StatelessWidget {
  final ArtistFull artist;
  final bool isTablet;
  final bool isWide;

  const _ArtistSliverAppBar({
    required this.artist,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        artist.thumbnails.isNotEmpty ? artist.thumbnails.last.url : null;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 280,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null)
              Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
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
              child: Text(
                artist.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
    return Row(
      children: [
        _FollowButton(artist: artist),
        const SizedBox(width: 12),
        _ArtistRadioButton(artist: artist),
      ],
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final ArtistFull artist;

  const _FollowButton({required this.artist});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _isFollowing = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final artist = await repo.getFollowedArtist(widget.artist.artistId);
      if (mounted) {
        setState(() {
          _isFollowing = artist != null;
          _isLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed:
          _isLoaded
              ? () async {
                final repo = ref.read(libraryRepositoryProvider);
                await repo.toggleFollowedArtist(
                  FollowedArtistModel(
                    artistId: widget.artist.artistId,
                    name: widget.artist.name,
                    thumbnailUrl:
                        widget.artist.thumbnails.isNotEmpty
                            ? widget.artist.thumbnails.last.url
                            : null,
                  ),
                );
                if (mounted) {
                  setState(() => _isFollowing = !_isFollowing);
                }
              }
              : null,
      child: Text(_isFollowing ? 'Following' : 'Follow'),
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
      icon: const Icon(Icons.radio),
      label: const Text('Artist Radio'),
    );
  }

  Future<void> _startArtistRadio(
    BuildContext context,
    WidgetRef ref,
    String videoId,
  ) async {
    try {
      final player = ref.read(playerStateProvider.notifier);
      final repo = ref.read(musicRepositoryProvider);
      final upNexts = await repo.getUpNexts(videoId);

      if (upNexts.isEmpty) return;

      final items = <MediaItem>[];
      for (final item in upNexts) {
        try {
          final url = await repo.getStreamUrl(item.videoId);
          items.add(
            MediaItem(
              id: item.videoId,
              title: item.title,
              artist: item.artists.name,
              album: item.album?.name,
              duration: Duration(seconds: item.duration),
              artUri:
                  item.thumbnails.isNotEmpty
                      ? Uri.parse(item.thumbnails.last.url)
                      : null,
              extras: {
                'url': url,
                'videoId': item.videoId,
                'isVideo': item.type == 'VIDEO',
              },
            ),
          );
        } catch (_) {}
      }

      if (items.isNotEmpty) {
        await player.playNow(items);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start artist radio: $e')),
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
                    const Expanded(child: ShimmerLoading(variant: ShimmerVariant.tile)),
                    SizedBox(width: 12),
                    const Expanded(child: ShimmerLoading(variant: ShimmerVariant.tile)),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
