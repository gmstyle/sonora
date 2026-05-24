import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/play_playlist_use_case_provider.dart';
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
              message: AppLocalizations.of(context)!.failedToLoadPlaylist,
              onRetry: () {
                ref.invalidate(playlistProvider(playlistId));
                ref.invalidate(playlistVideosProvider(playlistId));
              },
            ),
          ),
      data:
          (playlist) =>
              _PlaylistContent(playlist: playlist, videosAsync: videosAsync),
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
              message: AppLocalizations.of(context)!.failedToLoadPlaylist,
              onRetry: () {
                ref.invalidate(playlistProvider(playlistId));
                ref.invalidate(playlistVideosProvider(playlistId));
              },
            ),
          ),
      data:
          (playlist) => _PlaylistContent(
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
              message: AppLocalizations.of(context)!.failedToLoadPlaylist,
              onRetry: () {
                ref.invalidate(playlistProvider(playlistId));
                ref.invalidate(playlistVideosProvider(playlistId));
              },
            ),
          ),
      data:
          (playlist) => _PlaylistContent(
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
          _PlaylistSliverAppBar(
            playlist: playlist,
            isTablet: isTablet,
            isWide: isWide,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, isWide ? 48 : 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlaylistActions(
                    playlist: playlist,
                    videosAsync: videosAsync,
                  ),
                  const SizedBox(height: 16),
                  videosAsync.when(
                    loading: () => _videoShimmerList(),
                    error:
                        (e, _) => ErrorRetryWidget(
                          message:
                              AppLocalizations.of(context)!.failedToLoadVideos,
                          onRetry:
                              () => ref.invalidate(
                                playlistVideosProvider(playlist.playlistId),
                              ),
                        ),
                    data: (videos) => _VideoTracklist(videos: videos),
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
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _placeholder(context),
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
                    AppLocalizations.of(
                      context,
                    )!.videoCount(playlist.videoCount),
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

  const _PlaylistActions({required this.playlist, required this.videosAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed:
              videosAsync is AsyncData && videosAsync.asData?.value != null
                  ? () =>
                      _playSequential(context, ref, videosAsync.asData!.value)
                  : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(AppLocalizations.of(context)!.playAll),
        ),
        FilledButton.icon(
          onPressed:
              videosAsync is AsyncData && videosAsync.asData?.value != null
                  ? () => _shufflePlay(context, ref, videosAsync.asData!.value)
                  : null,
          icon: const Icon(Icons.shuffle),
          label: Text(AppLocalizations.of(context)!.shufflePlay),
        ),
        FilledButton.tonalIcon(
          onPressed:
              videosAsync is AsyncData && videosAsync.asData?.value != null
                  ? () => _addToQueue(context, ref, videosAsync.asData!.value)
                  : null,
          icon: const Icon(Icons.queue_music),
          label: Text(AppLocalizations.of(context)!.addToQueue),
        ),
        _DownloadPlaylistButton(
          playlist: playlist,
          videosAsync: videosAsync,
          onDownload:
              videosAsync is AsyncData && videosAsync.asData?.value != null
                  ? () => _downloadPlaylist(
                    context,
                    ref,
                    playlist,
                    videosAsync.asData!.value,
                  )
                  : null,
        ),
        _LikePlaylistButton(playlist: playlist, videosAsync: videosAsync),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          tooltip: AppLocalizations.of(context)!.share,
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text:
                    'https://music.youtube.com/playlist?list=${playlist.playlistId}',
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
    List<VideoDetailed> videos,
  ) async {
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playPlaylistUseCaseProvider);
    try {
      // playIndex: -1 → nessuna risoluzione URL (nessun item viene riprodotto subito)
      final items = await useCase.execute(videos, playIndex: -1);
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.addedToQueue(items.length),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToAddToQueue(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _playSequential(
    BuildContext context,
    WidgetRef ref,
    List<VideoDetailed> videos,
  ) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.playingPlaylist(playlist.name));
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playPlaylistUseCaseProvider);
    try {
      final items = await useCase.execute(videos);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPlayPlaylist(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _shufflePlay(
    BuildContext context,
    WidgetRef ref,
    List<VideoDetailed> videos,
  ) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.shufflingPlaylist(playlist.name));
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playPlaylistUseCaseProvider);
    final shuffled = List<VideoDetailed>.from(videos)..shuffle();
    try {
      final items = await useCase.execute(shuffled);
      if (items.isNotEmpty) await player.playNow(items);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPlayPlaylist(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadPlaylist(
    BuildContext context,
    WidgetRef ref,
    PlaylistFull playlist,
    List<VideoDetailed> videos,
  ) async {
    const batchSize = 3;
    final notifier = ref.read(activeDownloadsProvider.notifier);
    final toDownload =
        videos.where((v) => !notifier.isDownloading(v.videoId)).toList();
    if (toDownload.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.allSongsAlreadyDownloading,
            ),
          ),
        );
      }
      return;
    }

    final alreadyDownloaded =
        ref
            .read(allDownloadsProvider)
            .asData
            ?.value
            .where((d) => toDownload.any((v) => v.videoId == d.videoId))
            .toList() ??
        [];
    if (alreadyDownloaded.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.alreadyDownloaded),
              content: Text(
                AppLocalizations.of(context)!.alreadyDownloadedSongs(
                  alreadyDownloaded.length,
                  playlist.name,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppLocalizations.of(context)!.continueAction),
                ),
              ],
            ),
      );
      if (proceed != true || !context.mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          )!.downloadingSongs(toDownload.length, playlist.name),
        ),
      ),
    );

    final alreadyDownloadedIds =
        alreadyDownloaded.map((d) => d.videoId).toSet();

    for (var i = 0; i < toDownload.length; i += batchSize) {
      final batch = toDownload.skip(i).take(batchSize);
      await Future.wait(
        batch.map((video) async {
          if (alreadyDownloadedIds.contains(video.videoId)) {
            await notifier.deleteDownload(video.videoId);
          }
          await notifier.startDownload(
            videoId: video.videoId,
            title: video.name,
            artist: video.artist.name,
            thumbnailUrl:
                video.thumbnails.isNotEmpty ? video.thumbnails.last.url : null,
            subdirectory: playlist.name,
          );
        }),
      );
    }
  }
}

class _LikePlaylistButton extends ConsumerWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;

  const _LikePlaylistButton({
    required this.playlist,
    required this.videosAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPlaylistProvider(playlist.playlistId));
    return likedAsync.when(
      loading:
          () => FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.favorite_border),
            label: Text(AppLocalizations.of(context)!.likePlaylist),
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return FilledButton.tonalIcon(
          onPressed: () async {
            final notifier = ref.read(libraryNotifierProvider.notifier);
            await notifier.toggleLikedPlaylist(
              LikedPlaylistModel(
                playlistId: playlist.playlistId,
                name: playlist.name,
                thumbnailUrl:
                    playlist.thumbnails.isNotEmpty
                        ? playlist.thumbnails.last.url
                        : null,
                videoCount: playlist.videoCount,
                addedAt: DateTime.now(),
              ),
            );
          },
          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
          label: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlikePlaylist
                : AppLocalizations.of(context)!.likePlaylist,
          ),
        );
      },
    );
  }
}

class _DownloadPlaylistButton extends ConsumerWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;
  final VoidCallback? onDownload;

  const _DownloadPlaylistButton({
    required this.playlist,
    required this.videosAsync,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final videos = videosAsync.asData?.value ?? [];
    final downloadedCount =
        videos.where((v) => downloadedIds.contains(v.videoId)).length;
    final totalCount = videos.length;
    final allDownloaded = totalCount > 0 && downloadedCount == totalCount;

    return FilledButton.tonalIcon(
      onPressed: onDownload,
      icon: Icon(allDownloaded ? Icons.check_circle : Icons.download),
      label: Text(
        downloadedCount > 0
            ? AppLocalizations.of(
              context,
            )!.downloadedCount(downloadedCount, totalCount)
            : AppLocalizations.of(context)!.downloadPlaylist,
      ),
    );
  }
}

class _VideoTracklist extends ConsumerWidget {
  final List<VideoDetailed> videos;

  const _VideoTracklist({required this.videos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.playlistEmpty,
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
    final useCase = ref.read(playPlaylistUseCaseProvider);
    try {
      final items = await useCase.execute(videos, playIndex: startIndex);
      if (items.isNotEmpty) {
        await player.playNow(items, initialIndex: startIndex);
      }
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
