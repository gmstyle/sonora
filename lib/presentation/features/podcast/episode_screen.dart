import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/player_colors.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import 'providers/episode_provider.dart';

class EpisodeScreen extends ConsumerWidget {
  final String videoId;

  const EpisodeScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _EpisodeMobileLayout(videoId: videoId);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _EpisodeTabletLayout(videoId: videoId);
        } else {
          return _EpisodeWideLayout(videoId: videoId);
        }
      },
    );
  }
}

class _EpisodeMobileLayout extends ConsumerWidget {
  final String videoId;

  const _EpisodeMobileLayout({required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));

    return episodeAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadEpisode,
              onRetry: () => ref.invalidate(episodeProvider(videoId)),
            ),
          ),
      data: (episode) => _EpisodeContent(episode: episode),
    );
  }
}

class _EpisodeTabletLayout extends ConsumerWidget {
  final String videoId;

  const _EpisodeTabletLayout({required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));

    return episodeAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadEpisode,
              onRetry: () => ref.invalidate(episodeProvider(videoId)),
            ),
          ),
      data: (episode) => _EpisodeContent(episode: episode, isTablet: true),
    );
  }
}

class _EpisodeWideLayout extends ConsumerWidget {
  final String videoId;

  const _EpisodeWideLayout({required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodeAsync = ref.watch(episodeProvider(videoId));

    return episodeAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Scaffold(
            body: ErrorRetryWidget(
              message: AppLocalizations.of(context)!.failedToLoadEpisode,
              onRetry: () => ref.invalidate(episodeProvider(videoId)),
            ),
          ),
      data: (episode) => _EpisodeContent(episode: episode, isWide: true),
    );
  }
}

class _EpisodeContent extends ConsumerStatefulWidget {
  final EpisodeFull episode;
  final bool isTablet;
  final bool isWide;

  const _EpisodeContent({
    required this.episode,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_EpisodeContent> createState() => _EpisodeContentState();
}

class _EpisodeContentState extends ConsumerState<_EpisodeContent> {
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
          _EpisodeSliverAppBar(
            episode: widget.episode,
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
                  _EpisodeActions(episode: widget.episode),
                  if (widget.episode.description != null &&
                      widget.episode.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ExpandableText(text: widget.episode.description!),
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

class _EpisodeSliverAppBar extends StatelessWidget {
  final EpisodeFull episode;
  final bool isTablet;
  final bool isWide;
  final double scrollProgress;

  const _EpisodeSliverAppBar({
    required this.episode,
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
        episode.thumbnails.isNotEmpty ? episode.thumbnails.last.url : null;

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 340,
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          episode.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          GlassAppBarBackground(opacity: scrollProgress),
          FlexibleSpaceBar(
            background: _buildHeaderBackground(context, thumbnailUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context, String? thumbnailUrl) {
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
                        LucideIcons.headphones,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    episode.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.podcastName != null &&
                      episode.podcastName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.podcastName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.titleSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (episode.date != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.date!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.labelMuted,
                      ),
                      textAlign: TextAlign.center,
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
                        l10n.episode.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: colors.labelMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        episode.name,
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
                      if (episode.podcastName != null &&
                          episode.podcastName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          episode.podcastName!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.titleSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (episode.date != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          episode.date!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.subtitle,
                          ),
                        ),
                      ],
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
      LucideIcons.headphones,
      size: 80,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _EpisodeActions extends ConsumerWidget {
  final EpisodeFull episode;

  const _EpisodeActions({required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kCompactBreakpoint;
    final l10n = AppLocalizations.of(context)!;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SaveEpisodeButton(episode: episode, iconOnly: true),
                if (episode.podcastId != null && episode.podcastId!.isNotEmpty)
                  IconButton(
                    icon: const Icon(LucideIcons.micVocal),
                    tooltip: l10n.goToPodcast,
                    onPressed:
                        () => context.push('/podcast/${episode.podcastId}'),
                  ),
                IconButton(
                  icon: const Icon(LucideIcons.share2),
                  tooltip: l10n.share,
                  onPressed: () => _share(episode),
                ),
              ],
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: FilledButton(
                onPressed: () => _play(context, ref, episode),
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
          onPressed: () => _play(context, ref, episode),
          icon: const Icon(LucideIcons.play),
          label: Text(l10n.playNow),
        ),
        _SaveEpisodeButton(episode: episode),
        if (episode.podcastId != null && episode.podcastId!.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: () => context.push('/podcast/${episode.podcastId}'),
            icon: const Icon(LucideIcons.micVocal),
            label: Text(l10n.goToPodcast),
          ),
        IconButton(
          icon: const Icon(LucideIcons.share2),
          tooltip: l10n.share,
          onPressed: () => _share(episode),
        ),
      ],
    );
  }

  void _share(EpisodeFull episode) {
    SharePlus.instance.share(
      ShareParams(text: 'https://music.youtube.com/watch?v=${episode.videoId}'),
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    EpisodeFull episode,
  ) async {
    ref
        .read(actionFeedbackProvider.notifier)
        .report(AppLocalizations.of(context)!.playingPlaylist(episode.name));
    final player = ref.read(playerStateProvider.notifier);
    final podcastEpisode = PodcastEpisode(
      videoId: episode.videoId,
      browseId: episode.browseId,
      name: episode.name,
      description: episode.description,
      duration: episode.duration,
      date: episode.date,
      thumbnails: episode.thumbnails,
    );
    try {
      await player.playPodcast(
        [podcastEpisode],
        podcastBrowseId: episode.podcastId ?? episode.browseId,
        podcastName: episode.podcastName,
        authorName: episode.podcastName,
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

class _SaveEpisodeButton extends ConsumerWidget {
  final EpisodeFull episode;
  final bool iconOnly;

  const _SaveEpisodeButton({required this.episode, this.iconOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final likedAsync = ref.watch(likedEpisodeProvider(episode.videoId));

    return likedAsync.when(
      loading:
          () =>
              iconOnly
                  ? const IconButton(
                    onPressed: null,
                    icon: Icon(LucideIcons.bookmark),
                  )
                  : FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(LucideIcons.bookmark),
                    label: Text(l10n.saveEpisode),
                  ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isSaved = liked != null;
        if (iconOnly) {
          return IconButton(
            onPressed: () => _toggle(ref, isSaved),
            icon: Icon(
              isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
            ),
            color: isSaved ? Theme.of(context).colorScheme.primary : null,
            tooltip: isSaved ? l10n.unsaveEpisode : l10n.saveEpisode,
          );
        }
        return FilledButton.tonalIcon(
          onPressed: () => _toggle(ref, isSaved),
          icon: Icon(
            isSaved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
          ),
          label: Text(isSaved ? l10n.unsaveEpisode : l10n.saveEpisode),
          style:
              isSaved
                  ? FilledButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  )
                  : null,
        );
      },
    );
  }

  Future<void> _toggle(WidgetRef ref, bool isSaved) async {
    final notifier = ref.read(libraryNotifierProvider.notifier);
    await notifier.toggleLikedEpisode(
      LikedEpisodeModel(
        videoId: episode.videoId,
        browseId: episode.browseId,
        name: episode.name,
        podcastName: episode.podcastName,
        podcastBrowseId: episode.podcastId,
        thumbnailUrl:
            episode.thumbnails.isNotEmpty ? episode.thumbnails.last.url : null,
        durationSec: Parser.parseDuration(episode.duration),
        date: episode.date,
        addedAt: DateTime.now(),
      ),
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
