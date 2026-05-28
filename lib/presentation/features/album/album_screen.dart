import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/library_models.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/play_album_use_case_provider.dart';
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

class _AlbumContent extends ConsumerStatefulWidget {
  final AlbumFull album;
  final bool isTablet;
  final bool isWide;

  const _AlbumContent({
    required this.album,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_AlbumContent> createState() => _AlbumContentState();
}

class _AlbumContentState extends ConsumerState<_AlbumContent> {
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
        widget.isTablet || widget.isWide ? 360.0 : 300.0;
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
    final thumbnailUrl =
        widget.album.thumbnails.isNotEmpty
            ? widget.album.thumbnails.last.url
            : null;

    final totalDuration = widget.album.songs.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + Duration(seconds: song.duration ?? 0),
    );

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: widget.isTablet || widget.isWide ? 360 : 300,
            pinned: true,
            title: AnimatedOpacity(
              opacity:
                  _scrollProgress > 0.8 ? (_scrollProgress - 0.8) / 0.2 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Text(
                widget.album.name,
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
                      tag: 'album_art_${widget.album.albumId}',
                      child: CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, _, _) => _placeholderThumbnail(context),
                      ),
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
                      opacity: (1.0 - _scrollProgress * 1.5).clamp(0.0, 1.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.album.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.album.artist.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (widget.album.year != null)
                                '${widget.album.year}',
                              '${widget.album.songs.length} ${widget.album.songs.length == 1 ? 'song' : 'songs'}',
                              _formatDuration(totalDuration),
                            ].join(' · '),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isWide ? 48 : 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _AlbumActions(album: widget.album),
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
    final trackNumberWidth =
        widget.album.songs.length >= 100
            ? 36.0
            : (widget.album.songs.length >= 10 ? 32.0 : 28.0);

    return Column(
      children: [
        for (int i = 0; i < widget.album.songs.length; i++)
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
                    videoId: widget.album.songs[i].videoId,
                    title: widget.album.songs[i].name,
                    artist: widget.album.songs[i].artist.name,
                    thumbnailUrl:
                        widget.album.songs[i].thumbnails.isNotEmpty
                            ? widget.album.songs[i].thumbnails.last.url
                            : null,
                    duration: widget.album.songs[i].duration,
                    albumName: widget.album.name,
                    albumId: widget.album.albumId,
                    artistId:
                        widget.album.songs[i].artist.artistId ??
                        widget.album.artist.artistId,
                    playCount: widget.album.songs[i].playCount,
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
    final useCase = ref.read(playAlbumUseCaseProvider);
    try {
      final items = await useCase.execute(widget.album.songs);
      if (items.isNotEmpty) {
        await player.playNow(items, initialIndex: startIndex);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play album: $e')));
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
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => _playSequential(context, ref, album),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play All'),
        ),
        FilledButton.icon(
          onPressed: () => _shufflePlay(context, ref, album),
          icon: const Icon(Icons.shuffle),
          label: const Text('Shuffle Play'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _addToQueue(context, ref, album),
          icon: const Icon(Icons.queue_music),
          label: const Text('Add to Queue'),
        ),
        _DownloadAlbumButton(
          album: album,
          onDownload: () => _downloadAlbum(context, ref, album),
        ),
        _LikeAlbumButton(album: album),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: 'Share',
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text:
                    'https://music.youtube.com/playlist?list=${album.albumId}',
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addToQueue(
    BuildContext context,
    WidgetRef ref,
    AlbumFull album,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playAlbumUseCaseProvider);
    try {
      // playIndex: -1 → nessuna risoluzione URL (nessun item viene riprodotto subito)
      final items = await useCase.execute(album.songs, playIndex: -1);
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${items.length} song${items.length == 1 ? '' : 's'} to queue',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add to queue: $e')));
      }
    }
  }

  Future<void> _playSequential(
    BuildContext context,
    WidgetRef ref,
    AlbumFull album,
  ) async {
    ref.read(actionFeedbackProvider.notifier).report('Playing ${album.name}…');
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playAlbumUseCaseProvider);
    try {
      final items = await useCase.execute(album.songs);
      if (items.isNotEmpty) await player.playNow(items, initialIndex: 0);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play album: $e')));
      }
    }
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    AlbumFull album,
  ) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report('Shuffling ${album.name}…');
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playAlbumUseCaseProvider);
    final shuffled = List<SongDetailed>.from(album.songs)..shuffle();
    try {
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play album: $e')));
      }
    }
  }

  Future<void> _downloadAlbum(
    BuildContext context,
    WidgetRef ref,
    AlbumFull album,
  ) async {
    const batchSize = 3;
    final notifier = ref.read(activeDownloadsProvider.notifier);
    final toDownload =
        album.songs.where((s) => !notifier.isDownloading(s.videoId)).toList();
    if (toDownload.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All songs already downloading')),
        );
      }
      return;
    }

    final alreadyDownloaded =
        ref
            .read(allDownloadsProvider)
            .asData
            ?.value
            .where((d) => toDownload.any((s) => s.videoId == d.videoId))
            .toList() ??
        [];
    if (alreadyDownloaded.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Already downloaded'),
              content: Text(
                '${alreadyDownloaded.length} song${alreadyDownloaded.length > 1 ? 's' : ''} '
                'from ${album.name} ${alreadyDownloaded.length > 1 ? 'are' : 'is'} already downloaded. '
                'Downloading again will overwrite existing files. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
      );
      if (proceed != true || !context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading ${toDownload.length} songs from ${album.name}…',
        ),
      ),
    );

    final alreadyDownloadedIds =
        alreadyDownloaded.map((d) => d.videoId).toSet();

    for (var i = 0; i < toDownload.length; i += batchSize) {
      final batch = toDownload.skip(i).take(batchSize);
      await Future.wait(
        batch.map((song) async {
          if (alreadyDownloadedIds.contains(song.videoId)) {
            await notifier.deleteDownload(song.videoId);
          }
          await notifier.startDownload(
            videoId: song.videoId,
            title: song.name,
            artist: song.artist.name,
            thumbnailUrl:
                song.thumbnails.isNotEmpty ? song.thumbnails.last.url : null,
            subdirectory: album.name,
          );
        }),
      );
    }
  }
}

class _LikeAlbumButton extends ConsumerWidget {
  final AlbumFull album;

  const _LikeAlbumButton({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedAlbumProvider(album.albumId));
    return likedAsync.when(
      loading:
          () => FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.favorite_border),
            label: const Text('Like Album'),
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return FilledButton.tonalIcon(
          onPressed: () async {
            final notifier = ref.read(libraryNotifierProvider.notifier);
            await notifier.toggleLikedAlbum(
              LikedAlbumModel(
                albumId: album.albumId,
                name: album.name,
                artistName: album.artist.name,
                thumbnailUrl:
                    album.thumbnails.isNotEmpty
                        ? album.thumbnails.last.url
                        : null,
                year: album.year,
                addedAt: DateTime.now(),
              ),
            );
          },
          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
          label: Text(isLiked ? 'Unlike Album' : 'Like Album'),
        );
      },
    );
  }
}

class _DownloadAlbumButton extends ConsumerWidget {
  final AlbumFull album;
  final VoidCallback onDownload;

  const _DownloadAlbumButton({required this.album, required this.onDownload});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final downloadedCount =
        album.songs.where((s) => downloadedIds.contains(s.videoId)).length;
    final totalCount = album.songs.length;
    final allDownloaded = downloadedCount == totalCount;

    return FilledButton.tonalIcon(
      onPressed: onDownload,
      icon: Icon(allDownloaded ? Icons.check_circle : Icons.download),
      label: Text(
        downloadedCount > 0
            ? 'Downloaded $downloadedCount/$totalCount'
            : 'Download Album',
      ),
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
