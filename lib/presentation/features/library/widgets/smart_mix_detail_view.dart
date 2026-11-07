import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sonora/core/constants/app_constants.dart';

import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/detail_actions_bar.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/entity_wide_body.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/smart_mix_card.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/glass_app_bar_background.dart';
import '../../../providers/smart_playlists_provider.dart';
import '../../../providers/play_smart_mix_use_case_provider.dart';

class SmartMixDetailView extends ConsumerStatefulWidget {
  final String type;

  const SmartMixDetailView({super.key, required this.type});

  @override
  ConsumerState<SmartMixDetailView> createState() => _SmartMixDetailViewState();
}

class _SmartMixDetailViewState extends ConsumerState<SmartMixDetailView> {
  late final ScrollController _scrollController;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    const double expandedHeight = 260.0;
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

  SmartMixType _getMixType() {
    return SmartMixType.values.firstWhere(
      (e) => e.name == widget.type,
      orElse: () => SmartMixType.mostPlayed,
    );
  }

  LinearGradient _getGradient(SmartMixType type) => smartMixGradient(type);

  IconData _getIcon(SmartMixType type) {
    switch (type) {
      case SmartMixType.mostPlayed:
        return LucideIcons.flame;
      case SmartMixType.recentlyPlayed:
        return LucideIcons.history;
      case SmartMixType.forgottenFavorites:
        return LucideIcons.heart;
    }
  }

  String _getTitle(SmartMixType type, AppLocalizations l10n) {
    switch (type) {
      case SmartMixType.mostPlayed:
        return l10n.mostPlayed;
      case SmartMixType.recentlyPlayed:
        return l10n.recentlyPlayed;
      case SmartMixType.forgottenFavorites:
        return l10n.forgottenFavorites;
    }
  }

  String _getDescription(SmartMixType type, AppLocalizations l10n) {
    switch (type) {
      case SmartMixType.mostPlayed:
        return l10n.mostPlayedDesc;
      case SmartMixType.recentlyPlayed:
        return l10n.recentlyPlayedDesc;
      case SmartMixType.forgottenFavorites:
        return l10n.forgottenFavoritesDesc;
    }
  }

  Future<void> _playFrom(List<dynamic> songs, int index) async {
    if (songs.isEmpty) return;
    final player = ref.read(playerStateProvider.notifier);
    await player.playSmartMix(songs, startIndex: index);
  }

  Future<void> _playSong(
    String videoId, {
    bool isVideo = false,
    bool isExplicit = false,
  }) async {
    final player = ref.read(playerStateProvider.notifier);
    await player.playVideoId(videoId, isVideo: isVideo, isExplicit: isExplicit);
  }

  Future<void> _addToQueue(List<dynamic> songs, AppLocalizations l10n) async {
    final useCase = ref.read(playSmartMixUseCaseProvider);
    final player = ref.read(playerStateProvider.notifier);
    final items = await useCase.execute(songs: songs, playIndex: -1);
    try {
      if (items.isNotEmpty) await player.addAllToQueue(items);
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.addedToQueue(items.length));
    } catch (e) {
      debugPrint('Failed to add smart mix to queue: $e');
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mixType = _getMixType();
    final gradient = _getGradient(mixType);
    final title = _getTitle(mixType, l10n);
    final description = _getDescription(mixType, l10n);

    // Watch the correct stream provider based on type
    final AsyncValue<List<dynamic>> songsAsync = (() {
      switch (mixType) {
        case SmartMixType.mostPlayed:
          return ref.watch(mostPlayedSongsProvider);
        case SmartMixType.recentlyPlayed:
          return ref.watch(recentlyPlayedSongsProvider);
        case SmartMixType.forgottenFavorites:
          return ref.watch(forgottenFavoritesProvider);
      }
    })();

    final theme = Theme.of(context);

    return Scaffold(
      body: songsAsync.when(
        loading: () => const _SmartMixShimmer(),
        error: (e, _) => ErrorRetryWidget(
          message: e.toString(),
          onRetry: () {
            switch (mixType) {
              case SmartMixType.mostPlayed:
                ref.invalidate(mostPlayedSongsProvider);
                break;
              case SmartMixType.recentlyPlayed:
                ref.invalidate(recentlyPlayedSongsProvider);
                break;
              case SmartMixType.forgottenFavorites:
                ref.invalidate(forgottenFavoritesProvider);
                break;
            }
          },
        ),
        data: (songs) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kExpandedBreakpoint;
              final pad = entityHorizontalPadding(
                constraints.maxWidth,
                shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
              );
              Widget capTracks(Widget sliver) {
                if (!wide) return sliver;
                return SliverConstrainedCrossAxis(
                  maxExtent: kEntityTrackMaxWidth,
                  sliver: sliver,
                );
              }

              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ── Header SliverAppBar with Gradient & Icon ─────────────────
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    stretch: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: Stack(
                      fit: StackFit.expand,
                      children: [
                        GlassAppBarBackground(opacity: _scrollProgress),
                        FlexibleSpaceBar(
                          centerTitle: true,
                          title: _scrollProgress > 0.6
                              ? Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(gradient: gradient),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      theme.colorScheme.surface.withValues(
                                        alpha: 0.8,
                                      ),
                                      theme.colorScheme.surface,
                                    ],
                                    stops: const [0.0, 0.85, 1.0],
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: (1.0 - _scrollProgress * 2.0).clamp(
                                  0.0,
                                  1.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 32),
                                    Icon(
                                      _getIcon(mixType),
                                      size: 72,
                                      color: SonoraPulseTokens.onBrandGraphic
                                          .withValues(alpha: 0.95),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: pad,
                                      ),
                                      child: Text(
                                        title,
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: pad,
                                      ),
                                      child: Text(
                                        description,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Action Buttons ───────────────────────────────────────────
                  if (songs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
                        child: DetailActionsBar(
                          secondary: [
                            DetailAction(
                              id: DetailActionId.queue,
                              icon: LucideIcons.listMusic,
                              label: l10n.addToQueue,
                              tooltip: l10n.addToQueue,
                              onPressed: () => _addToQueue(songs, l10n),
                            ),
                          ],
                          onPlay: () => _playFrom(songs, 0),
                          playLabel: l10n.playAll,
                          onShuffle: () {
                            final shuffled = List<dynamic>.from(songs)
                              ..shuffle();
                            _playFrom(shuffled, 0);
                          },
                          shuffleLabel: l10n.shufflePlay,
                        ),
                      ),
                    ),

                  // ── Song List ────────────────────────────────────────────────
                  if (songs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: EmptyStateWidget(
                          icon: LucideIcons.music,
                          title: "No songs available in this mix yet",
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        0,
                        pad,
                        24 + MediaQuery.of(context).padding.bottom,
                      ),
                      sliver: capTracks(
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final song = songs[index];
                            final videoId = song.videoId;
                            final title = song.title;
                            final artist = song.artist;
                            final thumbnailUrl = song.thumbnailUrl;
                            final duration = song.duration;
                            final isVideo = song.isVideo;

                            final isExplicit = song.isExplicit == true;

                            String? playCountStr;
                            if (mixType == SmartMixType.mostPlayed &&
                                song is HistoryModel) {
                              playCountStr = '${song.playCount}x';
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: SongTile(
                                videoId: videoId,
                                title: title,
                                artist: artist,
                                thumbnailUrl: thumbnailUrl,
                                duration: duration,
                                isVideo: isVideo,
                                playCount: playCountStr,
                                isExplicit: isExplicit,
                                artistId: song is LikedSongModel
                                    ? song.artistId
                                    : null,
                                albumId: song is LikedSongModel
                                    ? song.albumId
                                    : null,
                                onTap: () => _playSong(
                                  videoId,
                                  isVideo: isVideo,
                                  isExplicit: isExplicit,
                                ),
                              ),
                            );
                          }, childCount: songs.length),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SmartMixShimmer extends StatelessWidget {
  const _SmartMixShimmer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.surfaceContainerHighest;
    final highlightColor = scheme.surfaceContainerHigh;
    final bone = scheme.surfaceContainerHighest;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            flexibleSpace: FlexibleSpaceBar(
              background: ColoredBox(color: bone),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: bone,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: bone,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ColoredBox(
                        color: bone,
                        child: const SizedBox(width: 24, height: 24),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: bone,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ColoredBox(
                              color: bone,
                              child: const SizedBox(width: 150, height: 16),
                            ),
                            const SizedBox(height: 8),
                            ColoredBox(
                              color: bone,
                              child: const SizedBox(width: 100, height: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                childCount: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
