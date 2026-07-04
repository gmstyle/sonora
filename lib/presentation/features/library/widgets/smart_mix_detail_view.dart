import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sonora/core/constants/app_constants.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
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

  LinearGradient _getGradient(SmartMixType type) {
    switch (type) {
      case SmartMixType.mostPlayed:
        return const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SmartMixType.recentlyPlayed:
        return const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case SmartMixType.forgottenFavorites:
        return const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

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

  List<MediaItem> _mapToMediaItems(SmartMixType type, dynamic data) {
    if (data is List<HistoryModel>) {
      return data
          .map(
            (r) => MediaItem(
              id: r.videoId,
              title: r.title,
              artist: r.artist,
              artUri:
                  r.thumbnailUrl != null ? Uri.tryParse(r.thumbnailUrl!) : null,
              extras: {
                'videoId': r.videoId,
                'isVideo': r.isVideo,
                'needsUrl': true,
                'isExplicit': r.isExplicit,
              },
            ),
          )
          .toList();
    } else if (data is List<LikedSongModel>) {
      return data
          .map(
            (r) => MediaItem(
              id: r.videoId,
              title: r.title,
              artist: r.artist,
              artUri:
                  r.thumbnailUrl != null ? Uri.tryParse(r.thumbnailUrl!) : null,
              extras: {
                'videoId': r.videoId,
                'isVideo': r.isVideo,
                'needsUrl': true,
                'artistId': r.artistId,
                'albumId': r.albumId,
                'isExplicit': r.isExplicit,
              },
            ),
          )
          .toList();
    }
    return [];
  }

  Future<void> _playFrom(List<dynamic> songs, int index) async {
    if (songs.isEmpty) return;
    final player = ref.read(playerStateProvider.notifier);
    await player.playSmartMix(songs, startIndex: index);
  }

  Future<void> _addToQueue(List<dynamic> songs, AppLocalizations l10n) async {
    final useCase = ref.read(playSmartMixUseCaseProvider);
    final player = ref.read(playerStateProvider.notifier);
    final items = await useCase.execute(songs: songs, playIndex: -1);
    try {
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addedToQueue(items.length))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToAddToQueue(e.toString()))),
      );
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
    final AsyncValue<List<dynamic>> songsAsync =
        (() {
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
    final isTablet = MediaQuery.of(context).size.width >= kCompactBreakpoint;

    return Scaffold(
      body: songsAsync.when(
        loading: () => const _SmartMixShimmer(),
        error:
            (e, _) => ErrorRetryWidget(
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
          final items = _mapToMediaItems(mixType, songs);

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
                      title:
                          _scrollProgress > 0.6
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
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    title,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
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
              if (items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child:
                        !isTablet
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(LucideIcons.listMusic),
                                      onPressed: () => _addToQueue(songs, l10n),
                                      tooltip: l10n.addToQueue,
                                    ),
                                    IconButton(
                                      icon: const Icon(LucideIcons.shuffle),
                                      onPressed: () {
                                        final shuffled = List<dynamic>.from(
                                          songs,
                                        )..shuffle();
                                        _playFrom(shuffled, 0);
                                      },
                                      tooltip: l10n.shufflePlay,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: () => _playFrom(songs, 0),
                                    style: FilledButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Icon(
                                      LucideIcons.play,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _playFrom(songs, 0),
                                  icon: const Icon(LucideIcons.play),
                                  label: Text(l10n.playAll),
                                ),
                                FilledButton.icon(
                                  onPressed: () {
                                    final shuffled = List<dynamic>.from(songs)
                                      ..shuffle();
                                    _playFrom(shuffled, 0);
                                  },
                                  icon: const Icon(LucideIcons.shuffle),
                                  label: Text(l10n.shufflePlay),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _addToQueue(songs, l10n),
                                  icon: const Icon(LucideIcons.listMusic),
                                  label: Text(l10n.addToQueue),
                                ),
                              ],
                            ),
                  ),
                ),

              // ── Song List ────────────────────────────────────────────────
              if (items.isEmpty)
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
                  padding: EdgeInsets.only(
                    bottom: 24 + MediaQuery.of(context).padding.bottom,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: SongTile(
                          videoId: videoId,
                          title: title,
                          artist: artist,
                          thumbnailUrl: thumbnailUrl,
                          duration: duration,
                          isVideo: isVideo,
                          playCount: playCountStr,
                          isExplicit: isExplicit,
                          artistId:
                              song is LikedSongModel ? song.artistId : null,
                          albumId: song is LikedSongModel ? song.albumId : null,
                          onTap: () => _playFrom(songs, index),
                        ),
                      );
                    }, childCount: songs.length),
                  ),
                ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF48484A) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.white12),
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
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white12,
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
                      Container(width: 24, height: 24, color: Colors.white12),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 150,
                              height: 16,
                              color: Colors.white12,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 100,
                              height: 12,
                              color: Colors.white12,
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
