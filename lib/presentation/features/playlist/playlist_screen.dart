import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/theme/player_colors.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/play_playlist_use_case_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/start_radio_use_case_provider.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/entity_wide_body.dart';
import '../../shared/widgets/expandable_text.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/detail_actions_bar.dart';
import '../../shared/widgets/entity_banner_header.dart';
import '../../shared/widgets/detail_affinity_button.dart';
import 'providers/playlist_provider.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';

class PlaylistScreen extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;

  const PlaylistScreen({super.key, required this.playlistId, this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        if (isCompactShell(size)) {
          return _PlaylistMobileLayout(
            playlistId: playlistId,
            heroTag: heroTag,
            contentWidth: constraints.maxWidth,
          );
        } else if (size.width < kExpandedBreakpoint) {
          return _PlaylistTabletLayout(
            playlistId: playlistId,
            heroTag: heroTag,
            contentWidth: constraints.maxWidth,
          );
        } else {
          return _PlaylistWideLayout(
            playlistId: playlistId,
            heroTag: heroTag,
            contentWidth: constraints.maxWidth,
          );
        }
      },
    );
  }
}

class _PlaylistMobileLayout extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;
  final double contentWidth;

  const _PlaylistMobileLayout({
    required this.playlistId,
    required this.contentWidth,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));

    return metaAsync.when(
      loading: () => const Scaffold(body: _PlaylistShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadPlaylist,
          onRetry: () {
            ref.invalidate(playlistProvider(playlistId));
            ref.invalidate(playlistVideosProvider(playlistId));
          },
        ),
      ),
      data: (playlist) => _PlaylistContent(
        playlist: playlist,
        videosAsync: videosAsync,
        heroTag: heroTag,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _PlaylistTabletLayout extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;
  final double contentWidth;

  const _PlaylistTabletLayout({
    required this.playlistId,
    required this.contentWidth,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));

    return metaAsync.when(
      loading: () => const Scaffold(body: _PlaylistShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadPlaylist,
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
        heroTag: heroTag,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _PlaylistWideLayout extends ConsumerWidget {
  final String playlistId;
  final String? heroTag;
  final double contentWidth;

  const _PlaylistWideLayout({
    required this.playlistId,
    required this.contentWidth,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(playlistProvider(playlistId));
    final videosAsync = ref.watch(playlistVideosProvider(playlistId));

    return metaAsync.when(
      loading: () => const Scaffold(body: _PlaylistShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadPlaylist,
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
        heroTag: heroTag,
        contentWidth: contentWidth,
      ),
    );
  }
}

class _PlaylistContent extends ConsumerStatefulWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;
  final String? heroTag;

  const _PlaylistContent({
    required this.playlist,
    required this.videosAsync,
    required this.contentWidth,
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
    final double expandedHeight = EntityBannerHeader.expandedHeight(
      wide: widget.isWide,
      layout: widget.isTablet || widget.isWide
          ? EntityBannerLayout.cover
          : EntityBannerLayout.centered,
    );
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
            contentWidth: widget.contentWidth,
            scrollProgress: _scrollProgress,
            heroTag: widget.heroTag,
            actions: widget.isTablet || widget.isWide
                ? _PlaylistActions(
                    playlist: widget.playlist,
                    videosAsync: widget.videosAsync,
                  )
                : null,
          ),
          SliverPadding(
            padding: entityBodyPadding(
              widget.contentWidth,
              shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isTablet && !widget.isWide)
                    _PlaylistActions(
                      playlist: widget.playlist,
                      videosAsync: widget.videosAsync,
                    ),
                  const SizedBox(height: 16),
                  EntityWideBody(
                    about:
                        widget.playlist.description != null &&
                            widget.playlist.description!.isNotEmpty
                        ? ExpandableText(text: widget.playlist.description!)
                        : null,
                    list: widget.videosAsync.when(
                      loading: () => _videoShimmerList(),
                      error: (e, _) => ErrorRetryWidget(
                        message: AppLocalizations.of(context)!
                            .failedToLoadVideos,
                        onRetry: () => ref.invalidate(
                          playlistVideosProvider(widget.playlist.playlistId),
                        ),
                      ),
                      data: (videos) => _VideoTracklist(videos: videos),
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
  final double contentWidth;
  final double scrollProgress;
  final String? heroTag;
  final Widget? actions;

  const _PlaylistSliverAppBar({
    required this.playlist,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
    this.heroTag,
    this.actions,
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
    final thumbnailUrl = playlist.thumbnails.isNotEmpty
        ? playlist.thumbnails.last.url
        : null;

    return SliverAppBar(
      expandedHeight: EntityBannerHeader.expandedHeight(
        wide: isWide,
        layout: isTablet || isWide
            ? EntityBannerLayout.cover
            : EntityBannerLayout.centered,
      ),
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
    final l10n = AppLocalizations.of(context)!;
    final textAlign = isTabletOrWide ? TextAlign.start : TextAlign.center;

    return EntityBannerHeader(
      layout: isTabletOrWide
          ? EntityBannerLayout.cover
          : EntityBannerLayout.centered,
      eyebrow: l10n.entityKindPlaylist,
      title: playlist.name,
      explicit: playlist.isExplicit,
      meta: Column(
        crossAxisAlignment: isTabletOrWide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            displayArtists(playlist.artists),
            style:
                (isTabletOrWide
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: isTabletOrWide ? FontWeight.w600 : null,
                      color: colors.titleSecondary,
                    ),
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isTabletOrWide ? 6 : 4),
          Text(
            l10n.videoCount(playlist.videoCount),
            style:
                (isTabletOrWide
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: isTabletOrWide
                          ? colors.subtitle
                          : colors.labelMuted,
                    ),
            textAlign: textAlign,
          ),
        ],
      ),
      imageUrl: thumbnailUrl,
      heroTag: tag,
      placeholderIcon: LucideIcons.listVideo,
      scrollProgress: scrollProgress,
      wide: isWide,
      contentWidth: contentWidth,
      actions: actions,
    );
  }
}

class _PlaylistActions extends ConsumerWidget {
  final PlaylistFull playlist;
  final AsyncValue<List<VideoDetailed>> videosAsync;

  const _PlaylistActions({required this.playlist, required this.videosAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final videos = videosAsync.asData?.value;
    final hasVideos = videos != null && playableVideos(videos).isNotEmpty;

    final secondary = rankDetailActions([
      DetailAction(
        id: DetailActionId.queue,
        icon: LucideIcons.listMusic,
        label: l10n.addToQueue,
        tooltip: l10n.addToQueue,
        onPressed: hasVideos ? () => _addToQueue(context, ref, videos) : null,
      ),
      DetailAction(
        id: DetailActionId.save,
        icon: Icons.favorite_border,
        label: l10n.like,
        tooltip: l10n.like,
        buildControl: (context, compact) => _LikePlaylistButton(
          playlist: playlist,
          videosAsync: videosAsync,
          iconOnly: compact,
        ),
      ),
    ]);

    return DetailActionsBar(
      secondary: secondary,
      onPlay: hasVideos ? () => _playSequential(context, ref, videos) : null,
      playLabel: l10n.playAll,
      onShuffle: hasVideos ? () => _shufflePlay(context, ref, videos) : null,
      shuffleLabel: l10n.shufflePlay,
      alwaysShowOverflow: true,
      onOverflow: () {
        ContextMenuSheet.showForPlaylist(
          context,
          playlistId: playlist.playlistId,
          name: playlist.name,
          artist: displayArtists(playlist.artists),
          thumbnailUrl: playlist.thumbnails.isNotEmpty
              ? playlist.thumbnails.last.url
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
        ref
            .read(actionFeedbackProvider.notifier)
            .report(AppLocalizations.of(context)!.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add playlist to queue: $e');
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
      debugPrint('Failed to play playlist: $e');
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.failedToPlayPlaylist,
              kind: FeedbackKind.error,
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
    final useCase = ref.read(startRadioUseCaseProvider);

    try {
      // Prefer YouTube's native shuffle watch playlist when available.
      var playlistId = playlist.playlistId;
      if (playlistId.startsWith('VL')) {
        playlistId = playlistId.substring(2);
      }
      final result = await useCase.execute(
        videos.isNotEmpty ? videos.first.videoId : '',
        playlistId: playlistId,
        radio: false,
        shuffle: true,
      );
      await player.playNow([result.firstItem]);
      if (result.remaining.isNotEmpty) {
        player.addAllToQueue(useCase.toPendingItems(result.remaining));
      }
    } catch (_) {
      final shuffled = List<VideoDetailed>.from(videos)..shuffle();
      try {
        await player.playPlaylist(shuffled, startIndex: 0);
      } catch (e) {
        debugPrint('Failed to shuffle play playlist: $e');
        if (context.mounted) {
          ref
              .read(actionFeedbackProvider.notifier)
              .report(
                AppLocalizations.of(context)!.failedToPlayPlaylist,
                kind: FeedbackKind.error,
              );
        }
      }
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
    final l10n = AppLocalizations.of(context)!;
    final likedAsync = ref.watch(likedPlaylistProvider(playlist.playlistId));
    return likedAsync.when(
      loading: () => DetailAffinityButton(
        iconOnly: iconOnly,
        isActive: false,
        enabled: false,
        idleIcon: DetailAffinityButton.likeIdle,
        activeIcon: DetailAffinityButton.likeActive,
        idleLabel: l10n.like,
        activeLabel: l10n.liked,
        activeColor: DetailAffinityButton.likeColor(
          Theme.of(context).colorScheme,
        ),
        onPressed: null,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return DetailAffinityButton(
          iconOnly: iconOnly,
          isActive: isLiked,
          idleIcon: DetailAffinityButton.likeIdle,
          activeIcon: DetailAffinityButton.likeActive,
          idleLabel: l10n.like,
          activeLabel: l10n.liked,
          activeColor: DetailAffinityButton.likeColor(
            Theme.of(context).colorScheme,
          ),
          onPressed: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedPlaylist(
                  LikedPlaylistModel(
                    playlistId: playlist.playlistId,
                    name: playlist.name,
                    thumbnailUrl: playlist.thumbnails.isNotEmpty
                        ? playlist.thumbnails.last.url
                        : null,
                    videoCount: playlist.videoCount,
                    addedAt: DateTime.now(),
                  ),
                );
          },
        );
      },
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
            artist: displayArtists(videos[i].artists),
            artists: videos[i].artists,
            artistId: primaryArtistId(videos[i].artists),
            thumbnailUrl: videos[i].thumbnails.isNotEmpty
                ? videos[i].thumbnails.last.url
                : null,
            duration: videos[i].duration,
            isVideo: true,
            isExplicit: videos[i].isExplicit,
            isPlayable: videos[i].isPlayable,
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
    final track = videos[startIndex];
    if (!track.isPlayable) {
      if (context.mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(
              AppLocalizations.of(context)!.trackUnplayable(track.name),
              kind: FeedbackKind.error,
            );
      }
      return;
    }
    final player = ref.read(playerStateProvider.notifier);
    try {
      await player.playPlaylist(videos, startIndex: startIndex);
    } catch (e) {
      debugPrint('Failed to play playlist track: $e');
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
