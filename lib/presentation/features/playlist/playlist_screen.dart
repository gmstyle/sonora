import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/player_colors.dart';
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
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import 'providers/playlist_provider.dart';

class PlaylistScreen extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;

  const PlaylistScreen({super.key, required this.playlistId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _PlaylistMobileLayout(
            playlistId: playlistId,
            heroTag: heroTag,
          );
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _PlaylistTabletLayout(
            playlistId: playlistId,
            heroTag: heroTag,
          );
        } else {
          return _PlaylistWideLayout(playlistId: playlistId, heroTag: heroTag);
        }
      },
    );
  }
}

class _PlaylistMobileLayout extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;

  const _PlaylistMobileLayout({required this.playlistId, this.heroTag});

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
            heroTag: heroTag,
          ),
    );
  }
}

class _PlaylistTabletLayout extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;

  const _PlaylistTabletLayout({required this.playlistId, this.heroTag});

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
            heroTag: heroTag,
          ),
    );
  }
}

class _PlaylistWideLayout extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;

  const _PlaylistWideLayout({required this.playlistId, this.heroTag});

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
            heroTag: heroTag,
          ),
    );
  }
}

class _PlaylistContent extends ConsumerStatefulWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;
  final bool isTablet;
  final bool isWide;
  final String? heroTag;

  const _PlaylistContent({
    required this.playlist,
    required this.videosAsync,
    this.isTablet = false,
    this.isWide = false,
    this.heroTag,
  });

  @override
  ConsumerState<_PlaylistContent> createState() => _PlaylistContentState();
}

class _PlaylistContentState extends ConsumerState<_PlaylistContent> {
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
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _PlaylistSliverAppBar(
            playlist: widget.playlist,
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
                  _PlaylistActions(
                    playlist: widget.playlist,
                    videosAsync: widget.videosAsync,
                  ),
                  if (widget.playlist.description != null &&
                      widget.playlist.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ExpandableText(text: widget.playlist.description!),
                  ],
                  const SizedBox(height: 16),
                  widget.videosAsync.when(
                    loading: () => _videoShimmerList(),
                    error:
                        (e, _) => ErrorRetryWidget(
                          message:
                              AppLocalizations.of(context)!.failedToLoadVideos,
                          onRetry:
                              () => ref.invalidate(
                                playlistVideosProvider(
                                  widget.playlist.playlistId,
                                ),
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
  final double scrollProgress;
  final String? heroTag;

  const _PlaylistSliverAppBar({
    required this.playlist,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );

    final tag = heroTag ?? 'playlist_art_${playlist.playlistId}';
    final thumbnailUrl =
        playlist.thumbnails.isNotEmpty ? playlist.thumbnails.last.url : null;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 340,
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text.rich(
          TextSpan(
            children: [
              if (playlist.isExplicit)
                const WidgetSpan(
                  child: Padding(
                    padding: EdgeInsets.only(right: 6.0),
                    child: ExplicitBadge(),
                  ),
                  alignment: PlaceholderAlignment.middle,
                ),
              TextSpan(text: playlist.name),
            ],
          ),
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
            background: _buildHeaderBackground(context, thumbnailUrl, tag),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(
    BuildContext context,
    String? thumbnailUrl,
    String tag,
  ) {
    final isTabletOrWide = isTablet || isWide;
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);

    if (!isTabletOrWide) {
      final theme = Theme.of(context);
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
                      tag: tag,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _placeholder(context),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        LucideIcons.listVideo,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (playlist.isExplicit)
                          const WidgetSpan(
                            child: Padding(
                              padding: EdgeInsets.only(right: 6.0),
                              child: ExplicitBadge(),
                            ),
                            alignment: PlaceholderAlignment.middle,
                          ),
                        TextSpan(text: playlist.name),
                      ],
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.artist.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.titleSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.videoCount(playlist.videoCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.labelMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
                    tag: tag,
                    child: Container(
                      width: isWide ? 190 : 150,
                      height: isWide ? 190 : 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _placeholder(context),
                        ),
                      ),
                    ),
                  )
                else
                  _placeholder(context),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'PLAYLIST',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: colors.labelMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (playlist.isExplicit)
                              const WidgetSpan(
                                child: Padding(
                                  padding: EdgeInsets.only(right: 6.0),
                                  child: ExplicitBadge(),
                                ),
                                alignment: PlaceholderAlignment.middle,
                              ),
                            TextSpan(text: playlist.name),
                          ],
                        ),
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
                      Text(
                        playlist.artist.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.titleSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.videoCount(playlist.videoCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.subtitle,
                        ),
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

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      LucideIcons.listVideo,
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
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kCompactBreakpoint;
    final videos = videosAsync.asData?.value;
    final hasVideos = videos != null && videos.isNotEmpty;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LikePlaylistButton(
                  playlist: playlist,
                  videosAsync: videosAsync,
                  iconOnly: true,
                ),
                _DownloadPlaylistButton(
                  playlist: playlist,
                  videosAsync: videosAsync,
                  onDownload:
                      hasVideos
                          ? () =>
                              _downloadPlaylist(context, ref, playlist, videos)
                          : null,
                  iconOnly: true,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.shuffle),
                  onPressed:
                      hasVideos
                          ? () => _shufflePlay(context, ref, videos)
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
                            'https://music.youtube.com/playlist?list=${playlist.playlistId}',
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical),
                  onPressed: () {
                    ContextMenuSheet.showForPlaylist(
                      context,
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
              ],
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: FilledButton(
                onPressed:
                    hasVideos
                        ? () => _playSequential(context, ref, videos)
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
              hasVideos ? () => _playSequential(context, ref, videos) : null,
          icon: const Icon(LucideIcons.play),
          label: Text(AppLocalizations.of(context)!.playAll),
        ),
        FilledButton.icon(
          onPressed:
              hasVideos ? () => _shufflePlay(context, ref, videos) : null,
          icon: const Icon(LucideIcons.shuffle),
          label: Text(AppLocalizations.of(context)!.shufflePlay),
        ),
        FilledButton.tonalIcon(
          onPressed: hasVideos ? () => _addToQueue(context, ref, videos) : null,
          icon: const Icon(LucideIcons.listMusic),
          label: Text(AppLocalizations.of(context)!.addToQueue),
        ),
        _DownloadPlaylistButton(
          playlist: playlist,
          videosAsync: videosAsync,
          onDownload:
              hasVideos
                  ? () => _downloadPlaylist(context, ref, playlist, videos)
                  : null,
        ),
        _LikePlaylistButton(playlist: playlist, videosAsync: videosAsync),
        IconButton(
          icon: const Icon(LucideIcons.share2),
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
    try {
      await player.playPlaylist(videos, startIndex: 0);
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
    final shuffled = List<VideoDetailed>.from(videos)..shuffle();
    try {
      await player.playPlaylist(shuffled, startIndex: 0);
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
            isExplicit: video.isExplicit,
          );
        }),
      );
    }
  }
}

class _LikePlaylistButton extends ConsumerWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;
  final bool iconOnly;

  const _LikePlaylistButton({
    required this.playlist,
    required this.videosAsync,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPlaylistProvider(playlist.playlistId));
    return likedAsync.when(
      loading:
          () =>
              iconOnly
                  ? const IconButton(
                    onPressed: null,
                    icon: Icon(LucideIcons.heart),
                  )
                  : FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(LucideIcons.heart),
                    label: Text(AppLocalizations.of(context)!.likePlaylist),
                  ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        if (iconOnly) {
          return IconButton(
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
            icon: Icon(isLiked ? LucideIcons.heart : LucideIcons.heart),
            color: isLiked ? Theme.of(context).colorScheme.primary : null,
            tooltip:
                isLiked
                    ? AppLocalizations.of(context)!.unlikePlaylist
                    : AppLocalizations.of(context)!.likePlaylist,
          );
        }
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
          icon: Icon(isLiked ? LucideIcons.heart : LucideIcons.heart),
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
  final bool iconOnly;

  const _DownloadPlaylistButton({
    required this.playlist,
    required this.videosAsync,
    required this.onDownload,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final videos = videosAsync.asData?.value ?? [];
    final downloadedCount =
        videos.where((v) => downloadedIds.contains(v.videoId)).length;
    final totalCount = videos.length;
    final allDownloaded = totalCount > 0 && downloadedCount == totalCount;

    if (iconOnly) {
      return IconButton(
        onPressed: onDownload,
        icon: Icon(
          allDownloaded ? LucideIcons.checkCircle : LucideIcons.download,
        ),
        color:
            downloadedCount > 0 ? Theme.of(context).colorScheme.primary : null,
        tooltip:
            downloadedCount > 0
                ? AppLocalizations.of(
                  context,
                )!.downloadedCount(downloadedCount, totalCount)
                : AppLocalizations.of(context)!.downloadPlaylist,
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onDownload,
      icon: Icon(
        allDownloaded ? LucideIcons.checkCircle : LucideIcons.download,
      ),
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
            artistId: videos[i].artist.artistId,
            thumbnailUrl:
                videos[i].thumbnails.isNotEmpty
                    ? videos[i].thumbnails.last.url
                    : null,
            duration: videos[i].duration,
            isVideo: true,
            isExplicit: videos[i].isExplicit,
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
    final video = videos[startIndex];
    try {
      await player.playVideoId(
        video.videoId,
        isVideo: true,
        isExplicit: video.isExplicit,
      );
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
