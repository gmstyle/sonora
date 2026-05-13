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
import 'providers/album_provider.dart';

class AlbumScreen extends ConsumerWidget {
  final String albumId;

  const AlbumScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _AlbumMobileLayout(albumId: albumId);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _AlbumTabletLayout(albumId: albumId);
        } else {
          return _AlbumWideLayout(albumId: albumId);
        }
      },
    );
  }
}

class _AlbumMobileLayout extends ConsumerWidget {
  final String albumId;

  const _AlbumMobileLayout({required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumProvider(albumId));

    return albumAsync.when(
      loading: () => const Scaffold(body: _AlbumShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: 'Failed to load album',
              onRetry: () => ref.invalidate(albumProvider(albumId)),
            ),
          ),
      data: (album) => _AlbumContent(album: album),
    );
  }
}

class _AlbumTabletLayout extends ConsumerWidget {
  final String albumId;

  const _AlbumTabletLayout({required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumProvider(albumId));

    return albumAsync.when(
      loading: () => const Scaffold(body: _AlbumShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: 'Failed to load album',
              onRetry: () => ref.invalidate(albumProvider(albumId)),
            ),
          ),
      data: (album) => _AlbumContent(album: album, isTablet: true),
    );
  }
}

class _AlbumWideLayout extends ConsumerWidget {
  final String albumId;

  const _AlbumWideLayout({required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumProvider(albumId));

    return albumAsync.when(
      loading: () => const Scaffold(body: _AlbumShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: 'Failed to load album',
              onRetry: () => ref.invalidate(albumProvider(albumId)),
            ),
          ),
      data: (album) => _AlbumContent(album: album, isWide: true),
    );
  }
}

class _AlbumContent extends ConsumerWidget {
  final AlbumFull album;
  final bool isTablet;
  final bool isWide;

  const _AlbumContent({
    required this.album,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailUrl =
        album.thumbnails.isNotEmpty ? album.thumbnails.last.url : null;

    final totalDuration = album.songs.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + Duration(seconds: song.duration ?? 0),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet || isWide ? 360 : 300,
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
                          (_, _, _) => _placeholderThumbnail(context),
                    )
                  else
                    _placeholderThumbnail(context),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          album.artist.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (album.year != null) '${album.year}',
                            '${album.songs.length} ${album.songs.length == 1 ? 'song' : 'songs'}',
                            _formatDuration(totalDuration),
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              isWide ? 48 : 16,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _AlbumActions(album: album),
                  const SizedBox(height: 16),
                  _buildTracklist(context, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracklist(BuildContext context, WidgetRef ref) {
    final trackNumberWidth = album.songs.length >= 100 ? 36.0 : (album.songs.length >= 10 ? 32.0 : 28.0);

    return Column(
      children: [
        for (int i = 0; i < album.songs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: trackNumberWidth,
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: SongTile(
                    videoId: album.songs[i].videoId,
                    title: album.songs[i].name,
                    artist: album.songs[i].artist.name,
                    thumbnailUrl:
                        album.songs[i].thumbnails.isNotEmpty
                            ? album.songs[i].thumbnails.last.url
                            : null,
                    duration: album.songs[i].duration,
                    albumName: album.songs[i].album?.name,
                    onTap: () => _playAlbumFromIndex(context, ref, i),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _playAlbumFromIndex(
    BuildContext context,
    WidgetRef ref,
    int startIndex,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final repo = ref.read(musicRepositoryProvider);
    try {
      final items = <MediaItem>[];
      final urls = await Future.wait(
        album.songs.map((s) => repo.getStreamUrl(s.videoId)),
      );
      for (int i = 0; i < album.songs.length; i++) {
        final s = album.songs[i];
        items.add(
          MediaItem(
            id: s.videoId,
            title: s.name,
            artist: s.artist.name,
            album: s.album?.name,
            duration: Duration(seconds: s.duration ?? 0),
            artUri:
                s.thumbnails.isNotEmpty
                    ? Uri.parse(s.thumbnails.last.url)
                    : null,
            extras: {
              'url': urls[i],
              'videoId': s.videoId,
              'isVideo': false,
            },
          ),
        );
      }
      if (items.isNotEmpty) await player.playNow(items, initialIndex: startIndex);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play album: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _placeholderThumbnail(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.album,
        size: 80,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AlbumActions extends ConsumerWidget {
  final AlbumFull album;

  const _AlbumActions({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => _shufflePlay(context, ref, album),
          icon: const Icon(Icons.shuffle),
          label: const Text('Shuffle Play'),
        ),
        const SizedBox(width: 12),
        _LikeAlbumButton(album: album),
      ],
    );
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    AlbumFull album,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final repo = ref.read(musicRepositoryProvider);
    final songs = List<SongDetailed>.from(album.songs)..shuffle();
    try {
      final items = <MediaItem>[];
      final urls = await Future.wait(
        songs.map((s) => repo.getStreamUrl(s.videoId)),
      );
      for (int i = 0; i < songs.length; i++) {
        final s = songs[i];
        items.add(
          MediaItem(
            id: s.videoId,
            title: s.name,
            artist: s.artist.name,
            album: s.album?.name,
            duration: Duration(seconds: s.duration ?? 0),
            artUri:
                s.thumbnails.isNotEmpty
                    ? Uri.parse(s.thumbnails.last.url)
                    : null,
            extras: {
              'url': urls[i],
              'videoId': s.videoId,
              'isVideo': false,
            },
          ),
        );
      }
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play album: $e')),
        );
      }
    }
  }
}

class _LikeAlbumButton extends ConsumerStatefulWidget {
  final AlbumFull album;

  const _LikeAlbumButton({required this.album});

  @override
  ConsumerState<_LikeAlbumButton> createState() => _LikeAlbumButtonState();
}

class _LikeAlbumButtonState extends ConsumerState<_LikeAlbumButton> {
  bool _isLiked = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    if (widget.album.songs.isEmpty) {
      if (mounted) setState(() => _isLoaded = true);
      return;
    }
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final song = await repo.getLikedSong(widget.album.songs.first.videoId);
      if (mounted) {
        setState(() {
          _isLiked = song != null;
          _isLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed:
          _isLoaded
              ? () async {
                final repo = ref.read(libraryRepositoryProvider);
                if (_isLiked) {
                  for (final s in widget.album.songs) {
                    await repo.deleteLikedSong(s.videoId);
                  }
                } else {
                  for (final s in widget.album.songs) {
                    await repo.toggleLikedSong(
                      LikedSongModel(
                        videoId: s.videoId,
                        title: s.name,
                        artist: s.artist.name,
                        thumbnailUrl:
                            s.thumbnails.isNotEmpty
                                ? s.thumbnails.last.url
                                : null,
                        addedAt: DateTime.now(),
                      ),
                    );
                  }
                }
                if (mounted) setState(() => _isLiked = !_isLiked);
              }
              : null,
      icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
      label: Text(_isLiked ? 'Unlike Album' : 'Like Album'),
    );
  }
}

class _AlbumShimmer extends StatelessWidget {
  const _AlbumShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
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
                ...List.generate(
                  8,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: ShimmerLoading(variant: ShimmerVariant.tile),
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
