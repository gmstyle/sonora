import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../domain/models/library_models.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import 'widgets/player_controls.dart';
import 'widgets/progress_bar_widget.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/lyrics_view.dart';

enum PlayerSubView { none, lyrics, queue }

class FullPlayerContent extends ConsumerStatefulWidget {
  const FullPlayerContent({super.key});

  @override
  ConsumerState<FullPlayerContent> createState() => _FullPlayerContentState();
}

class _FullPlayerContentState extends ConsumerState<FullPlayerContent> {
  PlayerSubView _activeView = PlayerSubView.none;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final isVideo = currentSong.extras?['isVideo'] == true;
    final videoId = currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final artUrl = currentSong.artUri?.toString();
    final albumName = currentSong.album;
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewPadding;
    final hasSleepTimer = playerState.sleepTimerRemaining != null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight =
                constraints.maxHeight - padding.top - padding.bottom;
            final availableWidth = constraints.maxWidth;

            if (constraints.maxWidth < kCompactBreakpoint) {
              return _mobileLayout(
                theme,
                currentSong,
                isVideo,
                videoId,
                artUrl,
                albumName,
                playerState,
                playerNotifier,
                hasSleepTimer,
                availableHeight,
                availableWidth,
                padding.bottom,
              );
            } else if (constraints.maxWidth < kExpandedBreakpoint) {
              return _tabletLayout(
                theme,
                currentSong,
                isVideo,
                videoId,
                artUrl,
                albumName,
                playerState,
                playerNotifier,
                hasSleepTimer,
                availableHeight,
                availableWidth,
                padding.bottom,
              );
            } else {
              return _wideLayout(
                theme,
                currentSong,
                isVideo,
                videoId,
                artUrl,
                albumName,
                playerState,
                playerNotifier,
                hasSleepTimer,
                availableHeight,
                availableWidth,
                padding.bottom,
              );
            }
          },
        ),
      ),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────

  Widget _mobileLayout(
    ThemeData theme,
    MediaItem currentSong,
    bool isVideo,
    String videoId,
    String? artUrl,
    String? albumName,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
    bool hasSleepTimer,
    double availHeight,
    double availWidth,
    double bottomInset,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _topBar(albumName),
            const SizedBox(height: 24),
            Expanded(
              child:
                  _activeView == PlayerSubView.none
                      ? Center(
                        child: _artwork(
                          artUrl,
                          availWidth - 48,
                          isSwitching: playerState.isSwitching,
                        ),
                      )
                      : _activeView == PlayerSubView.lyrics
                      ? LyricsView(
                        videoId: videoId,
                        position: playerState.position,
                      )
                      : const QueueSheet(),
            ),
            const SizedBox(height: 32),
            _trackInfoAndLikeRow(currentSong, isVideo, albumName),
            const SizedBox(height: 16),
            _progressBar(playerState, videoId),
            const SizedBox(height: 16),
            const PlayerControls(),
            const SizedBox(height: 8),
            _bottomActionsRow(
              isVideo,
              playerState.sleepTimerRemaining != null,
              playerNotifier,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Tablet ───────────────────────────────────────────────────

  Widget _tabletLayout(
    ThemeData theme,
    MediaItem currentSong,
    bool isVideo,
    String videoId,
    String? artUrl,
    String? albumName,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
    bool hasSleepTimer,
    double availHeight,
    double availWidth,
    double bottomInset,
  ) {
    // 2-column layout for tablet
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _artwork(
                    artUrl,
                    min(availHeight - 100, availWidth / 2 - 48),
                    isSwitching: playerState.isSwitching,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(albumName),
                  const SizedBox(height: 24),
                  _trackInfoAndLikeRow(currentSong, isVideo, albumName),
                  const SizedBox(height: 16),
                  if (_activeView != PlayerSubView.none)
                    Expanded(
                      child:
                          _activeView == PlayerSubView.lyrics
                              ? LyricsView(
                                videoId: videoId,
                                position: playerState.position,
                              )
                              : const QueueSheet(),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 16),
                  _progressBar(playerState, videoId),
                  const SizedBox(height: 16),
                  const PlayerControls(),
                  const SizedBox(height: 8),
                  _bottomActionsRow(isVideo, hasSleepTimer, playerNotifier),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Wide ─────────────────────────────────────────────────────

  Widget _wideLayout(
    ThemeData theme,
    MediaItem currentSong,
    bool isVideo,
    String videoId,
    String? artUrl,
    String? albumName,
    PlayerState playerState,
    PlayerNotifier playerNotifier,
    bool hasSleepTimer,
    double availHeight,
    double availWidth,
    double bottomInset,
  ) {
    // More spacious 2-column layout for wide
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _artwork(
                    artUrl,
                    min(availHeight - 150, availWidth / 2 - 100),
                    isSwitching: playerState.isSwitching,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 80),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(albumName),
                  const SizedBox(height: 32),
                  _trackInfoAndLikeRow(currentSong, isVideo, albumName),
                  const SizedBox(height: 16),
                  if (_activeView != PlayerSubView.none)
                    Expanded(
                      child:
                          _activeView == PlayerSubView.lyrics
                              ? LyricsView(
                                videoId: videoId,
                                position: playerState.position,
                              )
                              : const QueueSheet(),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 16),
                  _progressBar(playerState, videoId),
                  const SizedBox(height: 24),
                  const PlayerControls(),
                  const SizedBox(height: 16),
                  _bottomActionsRow(isVideo, hasSleepTimer, playerNotifier),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────

  Widget _topBar(String? albumName) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: AppLocalizations.of(context)!.close,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.playingFrom,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              if (albumName != null)
                Text(
                  albumName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  AppLocalizations.of(context)!.nowPlaying,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        /*
        TODO: Add context menu for album/artist actions (e.g. view album, view artist) 
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            // Context menu logic
          },
        ), */
      ],
    );
  }

  Widget _artwork(String? artUrl, double size, {bool isSwitching = false}) {
    final clampedSize = size.clamp(150.0, 600.0);
    Widget content;
    if (isSwitching) {
      content = const ShimmerLoading(variant: ShimmerVariant.artworkLarge);
    } else if (artUrl != null) {
      content = CachedNetworkImage(
        imageUrl: artUrl,
        fit: BoxFit.cover,
        placeholder:
            (_, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
        errorWidget:
            (_, _, _) => Icon(
              Icons.music_note,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    } else {
      content = Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.music_note,
          size: 80,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Hero(
      tag: 'player_art',
      child: Material(
        elevation: 8,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: clampedSize,
            height: clampedSize,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _trackInfoAndLikeRow(MediaItem song, bool isVideo, String? albumName) {
    final theme = Theme.of(context);
    final viewCount = song.extras?['viewCount'] as int?;
    final publishDate = song.extras?['publishDate'] as String?;
    final statParts = <String>[];
    if (viewCount != null) statParts.add('${viewCount.toCompact()} ${AppLocalizations.of(context)!.views}');
    if (publishDate != null && publishDate.isNotEmpty) statParts.add(publishDate);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      song.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVideo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.mv,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                song.artist ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (statParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  statParts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        _likeButton(song),
      ],
    );
  }

  Widget _progressBar(PlayerState playerState, String videoId) {
    return ProgressBarWidget(
      position: playerState.position,
      duration: playerState.duration,
      seed: videoId.hashCode,
      onSeek: (pos) => ref.read(playerStateProvider.notifier).seek(pos),
    );
  }

  Widget _likeButton(MediaItem song) {
    final videoId = song.extras?['videoId'] as String? ?? song.id;
    final title = song.title;
    final artist = song.artist ?? AppLocalizations.of(context)!.unknownArtist;
    final thumbnailUrl = song.artUri?.toString();

    final likedAsync = ref.watch(likedSongProvider(videoId));
    return likedAsync.when(
      loading: () => const Icon(Icons.favorite_border, size: 28),
      error: (_, _) => const Icon(Icons.favorite_border, size: 28),
      data: (liked) {
        final isLiked = liked != null;
        return IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 28,
            color: isLiked ? Theme.of(context).colorScheme.error : null,
          ),
          onPressed: () {
            ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedSong(
                  LikedSongModel(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    addedAt: DateTime.now(),
                  ),
                );
          },
        );
      },
    );
  }

  Widget _bottomActionsRow(
    bool isVideo,
    bool hasTimer,
    PlayerNotifier playerNotifier,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        /* 
        TODO: Add device output selection (e.g. Chromecast, Bluetooth)
        IconButton(
          icon: const Icon(Icons.speaker_group_outlined),
          onPressed: () {},
          tooltip: AppLocalizations.of(context)!.devices,
          color: theme.colorScheme.onSurfaceVariant,
        ), */
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                final currentSong = ref.read(playerStateProvider).currentSong;
                final vId =
                    currentSong?.extras?['videoId'] as String? ??
                    currentSong?.id;
                if (vId != null) {
                  SharePlus.instance.share(
                    ShareParams(text: 'https://music.youtube.com/watch?v=$vId'),
                  );
                }
              },
              tooltip: AppLocalizations.of(context)!.share,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (!isVideo)
              IconButton(
                icon: Icon(
                  _activeView == PlayerSubView.lyrics
                      ? Icons.lyrics
                      : Icons.lyrics_outlined,
                  color:
                      _activeView == PlayerSubView.lyrics
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    _activeView =
                        _activeView == PlayerSubView.lyrics
                            ? PlayerSubView.none
                            : PlayerSubView.lyrics;
                  });
                },
                tooltip: AppLocalizations.of(context)!.lyrics,
              ),
            IconButton(
              icon: Icon(
                _activeView == PlayerSubView.queue
                    ? Icons.queue_music
                    : Icons.queue_music_outlined,
                color:
                    _activeView == PlayerSubView.queue
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _activeView =
                      _activeView == PlayerSubView.queue
                          ? PlayerSubView.none
                          : PlayerSubView.queue;
                });
              },
              tooltip: AppLocalizations.of(context)!.queue,
            ),
            IconButton(
              icon: Icon(
                Icons.timer,
                size: 22,
                color:
                    hasTimer
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => _showTimerDialog(context, playerNotifier),
              tooltip: hasTimer ? AppLocalizations.of(context)!.sleepTimerActive : AppLocalizations.of(context)!.sleepTimer,
            ),
          ],
        ),
      ],
    );
  }

  void _showTimerDialog(BuildContext context, PlayerNotifier notifier) {
    final options = [5, 10, 15, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.sleepTimer,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ...options.map(
                (minutes) => ListTile(
                  title: Text(
                    minutes >= 60
                        ? '${minutes ~/ 60} hour'
                        : '$minutes minutes',
                  ),
                  onTap: () {
                    notifier.setSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(ctx);
                  },
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.timer_off,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(context)!.cancelTimer,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  notifier.cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
