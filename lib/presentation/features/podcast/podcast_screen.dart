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
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/song_tile.dart';
import 'providers/podcast_provider.dart';

/// Index of [episodeIndex] within the subset of episodes that have a
/// playable [PodcastEpisode.videoId] (matches the filtering performed by
/// [PlayerNotifier.playPodcast] / [PlayPodcastUseCase]).
int playableIndexForEpisode(PodcastFull podcast, int episodeIndex) {
  final episode = podcast.episodes[episodeIndex];
  if (episode.videoId.isEmpty) return -1;
  final playable = podcast.episodes.where((e) => e.videoId.isNotEmpty).toList();
  return playable.indexWhere((e) => e.videoId == episode.videoId);
}

class PodcastScreen extends ConsumerWidget {
  final String browseId;

  const PodcastScreen({super.key, required this.browseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _PodcastMobileLayout(browseId: browseId);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _PodcastTabletLayout(browseId: browseId);
        } else {
          return _PodcastWideLayout(browseId: browseId);
        }
      },
    );
  }
}

class _PodcastMobileLayout extends ConsumerWidget {
  final String browseId;

  const _PodcastMobileLayout({required this.browseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastAsync = ref.watch(podcastProvider(browseId));

    return podcastAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadPodcast,
              onRetry: () => ref.invalidate(podcastProvider(browseId)),
            ),
          ),
      data: (podcast) => _PodcastContent(podcast: podcast),
    );
  }
}

class _PodcastTabletLayout extends ConsumerWidget {
  final String browseId;

  const _PodcastTabletLayout({required this.browseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastAsync = ref.watch(podcastProvider(browseId));

    return podcastAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadPodcast,
              onRetry: () => ref.invalidate(podcastProvider(browseId)),
            ),
          ),
      data: (podcast) => _PodcastContent(podcast: podcast, isTablet: true),
    );
  }
}

class _PodcastWideLayout extends ConsumerWidget {
  final String browseId;

  const _PodcastWideLayout({required this.browseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastAsync = ref.watch(podcastProvider(browseId));

    return podcastAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadPodcast,
              onRetry: () => ref.invalidate(podcastProvider(browseId)),
            ),
          ),
      data: (podcast) => _PodcastContent(podcast: podcast, isWide: true),
    );
  }
}

class _PodcastContent extends ConsumerStatefulWidget {
  final PodcastFull podcast;
  final bool isTablet;
  final bool isWide;

  const _PodcastContent({
    required this.podcast,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_PodcastContent> createState() => _PodcastContentState();
}

class _PodcastContentState extends ConsumerState<_PodcastContent> {
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _PodcastSliverAppBar(
            podcast: widget.podcast,
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
                  _PodcastActions(podcast: widget.podcast),
                  if (widget.podcast.description != null &&
                      widget.podcast.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ExpandableText(text: widget.podcast.description!),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '${widget.podcast.episodes.length} ${l10n.episodes}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EpisodeTracklist(podcast: widget.podcast),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastSliverAppBar extends StatelessWidget {
  final PodcastFull podcast;
  final bool isTablet;
  final bool isWide;
  final double scrollProgress;

  const _PodcastSliverAppBar({
    required this.podcast,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );

    final thumbnailUrl =
        podcast.thumbnails.isNotEmpty ? podcast.thumbnails.last.url : null;
    final authorName = podcast.author?.name;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 340,
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          podcast.name,
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
            background: _buildHeaderBackground(
              context,
              thumbnailUrl,
              authorName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(
    BuildContext context,
    String? thumbnailUrl,
    String? authorName,
  ) {
    final isTabletOrWide = isTablet || isWide;
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;

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
                    Container(
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
                        LucideIcons.micVocal,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    podcast.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (authorName != null && authorName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      authorName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.titleSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${podcast.episodes.length} ${l10n.episodes}',
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
                  Container(
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
                        'PODCAST',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: colors.labelMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        podcast.name,
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
                      if (authorName != null && authorName.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          authorName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.titleSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${podcast.episodes.length} ${l10n.episodes}',
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
    width: isWide ? 190 : 150,
    height: isWide ? 190 : 150,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Icon(
      LucideIcons.micVocal,
      size: 80,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _PodcastActions extends ConsumerWidget {
  final PodcastFull podcast;

  const _PodcastActions({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kCompactBreakpoint;
    final hasEpisodes = podcast.episodes.any((e) => e.videoId.isNotEmpty);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SubscribePodcastButton(podcast: podcast, iconOnly: true),
                _DownloadPodcastButton(
                  podcast: podcast,
                  onDownload:
                      hasEpisodes
                          ? () => _downloadPodcast(context, ref, podcast)
                          : null,
                  iconOnly: true,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.shuffle),
                  onPressed:
                      hasEpisodes ? () => _shufflePlay(context, ref) : null,
                  tooltip: AppLocalizations.of(context)!.shuffle,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.share2),
                  tooltip: AppLocalizations.of(context)!.share,
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'https://music.youtube.com/browse/${podcast.browseId}',
                      ),
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
                    hasEpisodes ? () => _playSequential(context, ref) : null,
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
          onPressed: hasEpisodes ? () => _playSequential(context, ref) : null,
          icon: const Icon(LucideIcons.play),
          label: Text(AppLocalizations.of(context)!.playAll),
        ),
        FilledButton.tonalIcon(
          onPressed: hasEpisodes ? () => _shufflePlay(context, ref) : null,
          icon: const Icon(LucideIcons.shuffle),
          label: Text(AppLocalizations.of(context)!.shufflePlay),
        ),
        _DownloadPodcastButton(
          podcast: podcast,
          onDownload:
              hasEpisodes
                  ? () => _downloadPodcast(context, ref, podcast)
                  : null,
        ),
        _SubscribePodcastButton(podcast: podcast),
        IconButton(
          icon: const Icon(LucideIcons.share2),
          tooltip: AppLocalizations.of(context)!.share,
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text: 'https://music.youtube.com/browse/${podcast.browseId}',
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _playSequential(BuildContext context, WidgetRef ref) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.playingPlaylist(podcast.name));
    final player = ref.read(playerStateProvider.notifier);
    try {
      await player.playPodcast(
        podcast.episodes,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        startIndex: 0,
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

  Future<void> _shufflePlay(BuildContext context, WidgetRef ref) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.shufflingPlaylist(podcast.name));
    final player = ref.read(playerStateProvider.notifier);
    final shuffled = List<PodcastEpisode>.from(podcast.episodes)..shuffle();
    try {
      await player.playPodcast(
        shuffled,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        startIndex: 0,
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

  Future<void> _downloadPodcast(
    BuildContext context,
    WidgetRef ref,
    PodcastFull podcast,
  ) async {
    const batchSize = 3;
    final notifier = ref.read(activeDownloadsProvider.notifier);
    final episodes = podcast.episodes.where((e) => e.videoId.isNotEmpty);
    final toDownload =
        episodes.where((e) => !notifier.isDownloading(e.videoId)).toList();
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
            .where((d) => toDownload.any((e) => e.videoId == d.videoId))
            .toList() ??
        [];
    if (alreadyDownloaded.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(l10n.alreadyDownloaded),
              content: Text(
                l10n.alreadyDownloadedSongs(
                  alreadyDownloaded.length,
                  podcast.name,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.continueAction),
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
          )!.downloadingSongs(toDownload.length, podcast.name),
        ),
      ),
    );

    final alreadyDownloadedIds =
        alreadyDownloaded.map((d) => d.videoId).toSet();

    for (var i = 0; i < toDownload.length; i += batchSize) {
      final batch = toDownload.skip(i).take(batchSize);
      await Future.wait(
        batch.map((episode) async {
          if (alreadyDownloadedIds.contains(episode.videoId)) {
            await notifier.deleteDownload(episode.videoId);
          }
          await notifier.startDownload(
            videoId: episode.videoId,
            title: episode.name,
            artist: podcast.author?.name ?? podcast.name,
            thumbnailUrl:
                episode.thumbnails.isNotEmpty
                    ? episode.thumbnails.last.url
                    : null,
            subdirectory: podcast.name,
            isVideo: false,
          );
        }),
      );
    }
  }
}

class _SubscribePodcastButton extends ConsumerWidget {
  final PodcastFull podcast;
  final bool iconOnly;

  const _SubscribePodcastButton({required this.podcast, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final likedAsync = ref.watch(likedPodcastProvider(podcast.browseId));
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
                    label: Text(l10n.subscribe),
                  ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSubscribed = liked != null;
        Future<void> toggle() async {
          final notifier = ref.read(libraryNotifierProvider.notifier);
          await notifier.toggleLikedPodcast(
            LikedPodcastModel(
              browseId: podcast.browseId,
              name: podcast.name,
              authorName: podcast.author?.name,
              authorId: podcast.author?.artistId,
              thumbnailUrl:
                  podcast.thumbnails.isNotEmpty
                      ? podcast.thumbnails.last.url
                      : null,
              episodeCount: podcast.episodes.length,
              addedAt: DateTime.now(),
            ),
          );
        }

        if (iconOnly) {
          return IconButton(
            onPressed: toggle,
            icon: const Icon(LucideIcons.heart),
            color: isSubscribed ? Theme.of(context).colorScheme.primary : null,
            tooltip: isSubscribed ? l10n.subscribed : l10n.subscribe,
          );
        }
        return FilledButton.tonalIcon(
          onPressed: toggle,
          icon: const Icon(LucideIcons.heart),
          label: Text(isSubscribed ? l10n.subscribed : l10n.subscribe),
          style:
              isSubscribed
                  ? FilledButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  )
                  : null,
        );
      },
    );
  }
}

class _DownloadPodcastButton extends ConsumerWidget {
  final PodcastFull podcast;
  final VoidCallback? onDownload;
  final bool iconOnly;

  const _DownloadPodcastButton({
    required this.podcast,
    required this.onDownload,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final playableEpisodes =
        podcast.episodes.where((e) => e.videoId.isNotEmpty).toList();
    final downloadedCount =
        playableEpisodes.where((e) => downloadedIds.contains(e.videoId)).length;
    final totalCount = playableEpisodes.length;
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
                ? l10n.downloadedCount(downloadedCount, totalCount)
                : l10n.downloadPodcast,
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onDownload,
      icon: Icon(
        allDownloaded ? LucideIcons.checkCircle : LucideIcons.download,
      ),
      label: Text(
        downloadedCount > 0
            ? l10n.downloadedCount(downloadedCount, totalCount)
            : l10n.downloadPodcast,
      ),
    );
  }
}

class _EpisodeTracklist extends ConsumerWidget {
  final PodcastFull podcast;

  const _EpisodeTracklist({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authorName = podcast.author?.name ?? podcast.name;

    if (podcast.episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            l10n.noContentAvailable,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < podcast.episodes.length; i++)
          SongTile(
            videoId: podcast.episodes[i].videoId,
            title: podcast.episodes[i].name,
            artist: authorName,
            artistId: podcast.author?.artistId,
            thumbnailUrl:
                podcast.episodes[i].thumbnails.isNotEmpty
                    ? podcast.episodes[i].thumbnails.last.url
                    : null,
            duration: Parser.parseDuration(podcast.episodes[i].duration),
            playCount: podcast.episodes[i].date,
            isVideo: false,
            onTap:
                playableIndexForEpisode(podcast, i) >= 0
                    ? () => _playFromIndex(
                      context,
                      ref,
                      playableIndexForEpisode(podcast, i),
                    )
                    : null,
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
    try {
      await player.playPodcast(
        podcast.episodes,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        startIndex: startIndex,
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
