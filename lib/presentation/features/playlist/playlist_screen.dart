import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/music_repository_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import 'providers/playlist_provider.dart';

class PlaylistScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _PlaylistMobileLayout(playlistId: playlistId);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _PlaylistTabletLayout(playlistId: playlistId);
        } else {
          return _PlaylistWideLayout(playlistId: playlistId);
        }
      },
    );
  }
}

class _PlaylistMobileLayout extends ConsumerWidget {
  final String playlistId;

  const _PlaylistMobileLayout({required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));

    return metaAsync.when(
      loading: () => const Scaffold(body: _PlaylistShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: 'Failed to load playlist',
              onRetry: () {
                ref.invalidate(playlistProvider(playlistId));
                ref.invalidate(playlistVideosProvider(playlistId));
              },
            ),
          ),
      data: (playlist) => _PlaylistContent(
        playlist: playlist,
        videosAsync: videosAsync,
      ),
    );
  }
}

class _PlaylistTabletLayout extends ConsumerWidget {
  final String playlistId;

  const _PlaylistTabletLayout({required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));

    return metaAsync.when(
      loading: () => const Scaffold(body: _PlaylistShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: 'Failed to load playlist',
              onRetry: () {
                ref.invalidate(playlistProvider(playlistId));
                ref.invalidate(playlistVideosProvider(playlistId));
              },
            ),
          ),
      data: (playlist) => _PlaylistContent(
        playlist: playlist,
        videosAsync: videosAsync,
        isTablet: true,
      ),
    );
  }
}

class _PlaylistWideLayout extends ConsumerWidget {
  final String playlistId;

  const _PlaylistWideLayout({required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));

    return metaAsync.when(
      loading: () => const Scaffold(body: _PlaylistShimmer()),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: 'Failed to load playlist',
              onRetry: () {
                ref.invalidate(playlistProvider(playlistId));
                ref.invalidate(playlistVideosProvider(playlistId));
              },
            ),
          ),
      data: (playlist) => _PlaylistContent(
        playlist: playlist,
        videosAsync: videosAsync,
        isWide: true,
      ),
    );
  }
}

class _PlaylistContent extends ConsumerWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;
  final bool isTablet;
  final bool isWide;

  const _PlaylistContent({
    required this.playlist,
    required this.videosAsync,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _PlaylistSliverAppBar(playlist: playlist, isTablet: isTablet, isWide: isWide),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, isWide ? 48 : 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlaylistActions(playlist: playlist, videosAsync: videosAsync),
                  const SizedBox(height: 16),
                  videosAsync.when(
                    loading: () => _videoShimmerList(),
                    error:
                        (e, _) => ErrorRetryWidget(
                          message: 'Failed to load videos',
                          onRetry:
                              () => ref.invalidate(
                                playlistVideosProvider(playlist.playlistId),
                              ),
                        ),
                    data: (videos) => _VideoTracklist(
                      videos: videos,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSliverAppBar extends StatelessWidget {
  final PlaylistFull playlist;
  final bool isTablet;
  final bool isWide;

  const _PlaylistSliverAppBar({
    required this.playlist,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        playlist.thumbnails.isNotEmpty ? playlist.thumbnails.last.url : null;

    return SliverAppBar(
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
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            else
              _placeholder(context),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
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
                    playlist.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.artist.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.videoCount} ${playlist.videoCount == 1 ? 'video' : 'videos'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.playlist_play,
      size: 80,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _PlaylistActions extends ConsumerWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;

  const _PlaylistActions({
    required this.playlist,
    required this.videosAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        FilledButton.icon(
          onPressed:
              videosAsync is AsyncData && videosAsync.asData?.value != null
                  ? () => _shufflePlay(context, ref, videosAsync.asData!.value)
                  : null,
          icon: const Icon(Icons.shuffle),
          label: const Text('Shuffle Play'),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add to Playlist — coming soon')),
            );
          },
          icon: const Icon(Icons.playlist_add),
          label: const Text('Add to Playlist'),
        ),
      ],
    );
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    List<VideoDetailed> videos,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final repo = ref.read(musicRepositoryProvider);
    final shuffled = List<VideoDetailed>.from(videos)..shuffle();
    try {
      final items = <MediaItem>[];
      final urls = await Future.wait(
        shuffled.map((v) => repo.getStreamUrl(v.videoId)),
      );
      for (int i = 0; i < shuffled.length; i++) {
        final v = shuffled[i];
        items.add(
          MediaItem(
            id: v.videoId,
            title: v.name,
            artist: v.artist.name,
            duration: Duration(seconds: v.duration ?? 0),
            artUri:
                v.thumbnails.isNotEmpty
                    ? Uri.parse(v.thumbnails.last.url)
                    : null,
            extras: {
              'url': urls[i],
              'videoId': v.videoId,
              'isVideo': true,
            },
          ),
        );
      }
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play playlist: $e')),
        );
      }
    }
  }
}

class _VideoTracklist extends ConsumerWidget {
  final List<VideoDetailed> videos;

  const _VideoTracklist({
    required this.videos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'This playlist is empty',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < videos.length; i++)
          SongTile(
            videoId: videos[i].videoId,
            title: videos[i].name,
            artist: videos[i].artist.name,
            thumbnailUrl:
                videos[i].thumbnails.isNotEmpty
                    ? videos[i].thumbnails.last.url
                    : null,
            duration: videos[i].duration,
            isVideo: true,
            onTap: () => _playFromIndex(context, ref, i),
          ),
      ],
    );
  }

  Future<void> _playFromIndex(
    BuildContext context,
    WidgetRef ref,
    int startIndex,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final repo = ref.read(musicRepositoryProvider);
    try {
      final items = <MediaItem>[];
      final urls = await Future.wait(
        videos.map((v) => repo.getStreamUrl(v.videoId)),
      );
      for (int i = 0; i < videos.length; i++) {
        final v = videos[i];
        items.add(
          MediaItem(
            id: v.videoId,
            title: v.name,
            artist: v.artist.name,
            duration: Duration(seconds: v.duration ?? 0),
            artUri:
                v.thumbnails.isNotEmpty
                    ? Uri.parse(v.thumbnails.last.url)
                    : null,
            extras: {
              'url': urls[i],
              'videoId': v.videoId,
              'isVideo': true,
            },
          ),
        );
      }
      if (items.isNotEmpty) await player.playNow(items, initialIndex: startIndex);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play: $e')),
        );
      }
    }
  }
}

Widget _videoShimmerList() => Column(
  children: List.generate(
    6,
    (_) => const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: ShimmerLoading(variant: ShimmerVariant.tile),
    ),
  ),
);

class _PlaylistShimmer extends StatelessWidget {
  const _PlaylistShimmer();

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
