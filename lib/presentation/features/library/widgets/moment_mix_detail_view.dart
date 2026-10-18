import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/moment_mix_provider.dart';
import '../../../providers/play_smart_mix_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/detail_actions_bar.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_app_bar_background.dart';
import '../../../shared/widgets/moment_mix_ask_card.dart';
import '../../../shared/widgets/song_tile.dart';
import '../providers/library_provider.dart';
import 'create_playlist_dialog.dart';
import 'playlist_detail_view.dart';

/// Preview of an Ask → Mix queue held in [momentMixProvider].
class MomentMixDetailView extends ConsumerStatefulWidget {
  const MomentMixDetailView({super.key});

  @override
  ConsumerState<MomentMixDetailView> createState() =>
      _MomentMixDetailViewState();
}

class _MomentMixDetailViewState extends ConsumerState<MomentMixDetailView> {
  late final ScrollController _scrollController;
  double _scrollProgress = 0.0;
  bool _saving = false;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF6A1B9A), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
      setState(() => _scrollProgress = progress);
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
      debugPrint('Failed to add moment mix to queue: $e');
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }

  Future<void> _savePlaylist(
    AppLocalizations l10n,
    String defaultName,
    List<dynamic> tracks,
  ) async {
    if (_saving || tracks.isEmpty) return;

    final name = await showDialog<String>(
      context: context,
      builder:
          (_) => CreatePlaylistDialog(
            initialName: defaultName,
            title: l10n.createPlaylist,
          ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      final playlist = await ref
          .read(libraryNotifierProvider.notifier)
          .createPlaylistWithTracks(name.trim(), tracks);
      ref.invalidate(playlistsProvider);
      if (!mounted) return;
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.momentMixSaved(playlist.name));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => PlaylistDetailView(
                playlist: playlist,
                onUpdated: () => ref.invalidate(playlistsProvider),
              ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to save moment mix playlist: $e');
      if (!mounted) return;
      ref
          .read(actionFeedbackProvider.notifier)
          .report(l10n.momentMixSaveFailed, kind: FeedbackKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mix = ref.watch(momentMixProvider);
    final theme = Theme.of(context);
    final title = momentMixTitle(l10n, mix.intent);
    final songs = mix.tracks;

    if (!mix.hasMix) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.pop(),
          ),
        ),
        body: EmptyStateWidget(
          icon: LucideIcons.sparkles,
          title: l10n.momentMixEmpty,
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.pop(),
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
                        decoration: const BoxDecoration(gradient: _gradient),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              theme.colorScheme.surface.withValues(alpha: 0.8),
                              theme.colorScheme.surface,
                            ],
                            stops: const [0.0, 0.85, 1.0],
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: (1.0 - _scrollProgress * 2.0).clamp(0.0, 1.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            Icon(
                              LucideIcons.sparkles,
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
                                style: theme.textTheme.headlineMedium?.copyWith(
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
                                l10n.momentMixTrackCount(songs.length),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: DetailActionsBar(
                secondary: [
                  DetailAction(
                    id: DetailActionId.queue,
                    icon: LucideIcons.listMusic,
                    label: l10n.addToQueue,
                    tooltip: l10n.addToQueue,
                    onPressed: () => _addToQueue(songs, l10n),
                  ),
                  DetailAction(
                    id: DetailActionId.save,
                    icon: LucideIcons.listPlus,
                    label: l10n.savePlaylist,
                    tooltip: l10n.savePlaylist,
                    onPressed:
                        _saving
                            ? null
                            : () => _savePlaylist(l10n, title, songs),
                  ),
                ],
                onPlay: () => _playFrom(songs, 0),
                playLabel: l10n.playAll,
                onShuffle: () {
                  final shuffled = List<dynamic>.from(songs)..shuffle();
                  _playFrom(shuffled, 0);
                },
                shuffleLabel: l10n.shufflePlay,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = songs[index];
                final videoId = song.videoId as String;
                final songTitle = song.title as String;
                final artist = song.artist as String;
                final thumbnailUrl = song.thumbnailUrl as String?;
                final duration = song.duration as int?;
                final isVideo = song.isVideo as bool? ?? false;
                final isExplicit = song.isExplicit == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SongTile(
                    videoId: videoId,
                    title: songTitle,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    duration: duration,
                    isVideo: isVideo,
                    isExplicit: isExplicit,
                    artistId: song is LikedSongModel ? song.artistId : null,
                    albumId: song is LikedSongModel ? song.albumId : null,
                    onTap:
                        () => _playSong(
                          videoId,
                          isVideo: isVideo,
                          isExplicit: isExplicit,
                        ),
                  ),
                );
              }, childCount: songs.length),
            ),
          ),
        ],
      ),
    );
  }
}
