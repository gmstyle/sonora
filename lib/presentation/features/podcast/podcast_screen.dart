import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/player_colors.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../providers/play_podcast_use_case_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/detail_actions_bar.dart';
import '../../shared/widgets/detail_affinity_button.dart';
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
      loading: () => const Scaffold(body: _PodcastShimmer()),
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
      loading: () => const Scaffold(body: _PodcastShimmer()),
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
      loading: () => const Scaffold(body: _PodcastShimmer()),
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
    final l10n = AppLocalizations.of(context)!;
    final hasEpisodes = podcast.episodes.any((e) => e.videoId.isNotEmpty);

    final secondary = rankDetailActions([
      DetailAction(
        id: DetailActionId.queue,
        icon: LucideIcons.listMusic,
        label: l10n.addToQueue,
        tooltip: l10n.addToQueue,
        onPressed: hasEpisodes ? () => _addToQueue(context, ref) : null,
      ),
      DetailAction(
        id: DetailActionId.save,
        icon: LucideIcons.bookmark,
        label: l10n.subscribe,
        tooltip: l10n.subscribe,
        buildControl:
            (context, compact) =>
                _SubscribePodcastButton(podcast: podcast, iconOnly: compact),
      ),
    ]);

    return DetailActionsBar(
      secondary: secondary,
      onPlay: hasEpisodes ? () => _playSequential(context, ref) : null,
      playLabel: l10n.playAll,
      onShuffle: hasEpisodes ? () => _shufflePlay(context, ref) : null,
      shuffleLabel: l10n.shufflePlay,
      alwaysShowOverflow: true,
      onOverflow: () {
        ContextMenuSheet.showForPodcast(
          context,
          browseId: podcast.browseId,
          name: podcast.name,
          author: podcast.author?.name,
          thumbnailUrl:
              podcast.thumbnails.isNotEmpty
                  ? podcast.thumbnails.last.url
                  : null,
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

  Future<void> _addToQueue(BuildContext context, WidgetRef ref) async {
    final player = ref.read(playerStateProvider.notifier);
    final useCase = ref.read(playPodcastUseCaseProvider);
    try {
      final episodes =
          podcast.episodes.where((e) => e.videoId.isNotEmpty).toList();
      if (episodes.isEmpty) return;
      final items = await useCase.execute(
        episodes,
        podcastBrowseId: podcast.browseId,
        podcastName: podcast.name,
        authorName: podcast.author?.name,
        authorId: podcast.author?.artistId,
        playIndex: -1,
      );
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(AppLocalizations.of(context)!.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add podcast to queue: $e');
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
      debugPrint('Failed to play podcast: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlay,
              kind: FeedbackKind.error,
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
      debugPrint('Failed to shuffle play podcast: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlay,
              kind: FeedbackKind.error,
            );
      }
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
          () => DetailAffinityButton(
            iconOnly: iconOnly,
            isActive: false,
            enabled: false,
            idleIcon: LucideIcons.bookmark,
            activeIcon: LucideIcons.bookmarkCheck,
            idleLabel: l10n.subscribe,
            activeLabel: l10n.subscribed,
            onPressed: null,
          ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSubscribed = liked != null;
        return DetailAffinityButton(
          iconOnly: iconOnly,
          isActive: isSubscribed,
          idleIcon: LucideIcons.bookmark,
          activeIcon: LucideIcons.bookmarkCheck,
          idleLabel: l10n.subscribe,
          activeLabel: l10n.subscribed,
          activeColor: Theme.of(context).colorScheme.primary,
          onPressed: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedPodcast(
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
          },
        );
      },
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
      debugPrint('Failed to play podcast episode: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlay,
              kind: FeedbackKind.error,
            );
      }
    }
  }
}

class _PodcastShimmer extends StatelessWidget {
  const _PodcastShimmer();

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
                ...List.generate(
                  10,
                  (_) => const ShimmerLoading(variant: ShimmerVariant.tile),
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
