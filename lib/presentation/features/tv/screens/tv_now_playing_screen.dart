import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/screen_keep_awake.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/equalizer_provider.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../providers/player_insights_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../player/player_navigation.dart';
import '../../player/widgets/equalizer_panel.dart';
import '../../player/widgets/player_insights_panel.dart';
import '../../player/widgets/player_shared_widgets.dart';
import '../tv_metrics.dart';
import '../widgets/tv_focusable.dart';

/// Opens the TV now-playing overlay (never the phone [openFullPlayer]).
void openTvNowPlaying(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  container.read(playerSubViewProvider.notifier).set(PlayerSubView.none);
  container.read(playerInsightsProvider.notifier).dismiss();
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const TvNowPlayingScreen(),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    ),
  );
}

class TvNowPlayingScreen extends ConsumerStatefulWidget {
  const TvNowPlayingScreen({super.key});

  @override
  ConsumerState<TvNowPlayingScreen> createState() => _TvNowPlayingScreenState();
}

class _TvNowPlayingScreenState extends ConsumerState<TvNowPlayingScreen> {
  late final PlayerSubViewNotifier _subViewNotifier;
  late final PlayerInsightsNotifier _insightsNotifier;
  PlayerSubView? _keepAwakeForView;

  @override
  void initState() {
    super.initState();
    _subViewNotifier = ref.read(playerSubViewProvider.notifier);
    _insightsNotifier = ref.read(playerInsightsProvider.notifier);
  }

  @override
  void dispose() {
    ScreenKeepAwake.disable();
    final subView = _subViewNotifier;
    final insights = _insightsNotifier;
    Future.microtask(() {
      try {
        subView.set(PlayerSubView.none);
        insights.dismiss();
      } catch (_) {
        // Provider container already torn down (e.g. widget tests).
      }
    });
    super.dispose();
  }

  void _syncLyricsKeepAwake(PlayerSubView view) {
    if (_keepAwakeForView == view) return;
    _keepAwakeForView = view;
    if (view == PlayerSubView.lyrics) {
      ScreenKeepAwake.enable();
    } else {
      ScreenKeepAwake.disable();
    }
  }

  bool _handleBack() {
    final insightsOpen = ref.read(playerInsightsProvider).isOpen;
    if (insightsOpen) {
      ref.read(playerInsightsProvider.notifier).dismiss();
      return true;
    }
    final activeView = ref.read(playerSubViewProvider);
    if (activeView != PlayerSubView.none) {
      ref.read(playerSubViewProvider.notifier).set(PlayerSubView.none);
      return true;
    }
    return false;
  }

  void _toggleSubView(PlayerSubView view) {
    ref.read(playerInsightsProvider.notifier).dismiss();
    final current = ref.read(playerSubViewProvider);
    ref
        .read(playerSubViewProvider.notifier)
        .set(current == view ? PlayerSubView.none : view);
  }

  void _openOverflow(MediaItem song) {
    final track = QueueTrack.fromMediaItem(song);
    final albumName = song.album;
    if (track.isEpisode) {
      ContextMenuSheet.showForEpisode(
        context,
        videoId: track.videoId,
        name: song.title,
        podcastName: song.artist,
        podcastBrowseId: track.podcastBrowseId,
        thumbnailUrl: song.artUri?.toString(),
        date: track.publishDate,
        onGoToPodcast: (podcastBrowseId) {
          closeFullPlayerAndNavigate(context, '/podcast/$podcastBrowseId');
        },
      );
      return;
    }
    ContextMenuSheet.showForNowPlaying(
      context,
      videoId: track.videoId,
      title: song.title,
      artist: song.artist ?? '',
      artistsJson: track.artistsJson,
      thumbnailUrl: song.artUri?.toString(),
      duration: song.duration?.inSeconds,
      albumName: albumName,
      isVideo: track.isVideo,
      artistId: track.artistId,
      albumId: track.albumId,
      isExplicit: track.isExplicit,
      onGoToArtist: (artistId) {
        closeFullPlayerAndNavigate(context, '/artist/$artistId');
      },
      onGoToAlbum: (albumId) {
        closeFullPlayerAndNavigate(context, '/album/$albumId');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(playerStateProvider.notifier);
    final activeView = ref.watch(playerSubViewProvider);
    final insightsOpen = ref.watch(playerInsightsProvider).isOpen;
    final isOffline = ref.watch(isOfflineProvider);
    final eqEnabled = ref.watch(equalizerNotifierProvider).enabled;
    final askCaps = ref.watch(askCapabilitiesProvider).asData?.value;

    ref.listen<PlayerSubView>(playerSubViewProvider, (prev, next) {
      _syncLyricsKeepAwake(next);
    });
    _syncLyricsKeepAwake(activeView);

    if (song == null) {
      return Scaffold(
        body: Center(
          child: TvFocusable(
            autofocus: true,
            onSelect: () => Navigator.of(context).maybePop(),
            child: Text(l10n.noConnectionMessage),
          ),
        ),
      );
    }

    final track = QueueTrack.fromMediaItem(song);
    final videoId = track.videoId;
    final isEpisode = track.isEpisode;
    final isVideo = track.isVideo;
    final podcastBrowseId = track.podcastBrowseId;
    final showRelated =
        !isEpisode || (podcastBrowseId != null && podcastBrowseId.isNotEmpty);
    final showPlayerAsk =
        !isEpisode && !isOffline && (askCaps?.canPlayerInsights ?? false);
    final isPanelOpen = activeView != PlayerSubView.none;
    final blocked = playerState.isBlocked;
    final hasTimer = playerState.hasSleepTimer;

    return PopScope(
      canPop: !insightsOpen && activeView == PlayerSubView.none,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: DpadRegion(
            memoryKey: 'tv/now-playing',
            debugLabel: 'tv/now-playing',
            child: Padding(
              padding: const EdgeInsets.all(TvMetrics.horizontalPadding),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Center(child: _Artwork(song: song))),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    song.artist ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            TvFocusable(
                              onSelect:
                                  () => toggleMediaItemLike(context, ref, song),
                              child: IgnorePointer(
                                child: buildLikeButton(context, ref, song),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TvFocusable(
                              onSelect: () => _openOverflow(song),
                              child: const _TransportIcon(
                                LucideIcons.ellipsisVertical,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child:
                                isPanelOpen
                                    ? KeyedSubtree(
                                      key: ValueKey(activeView),
                                      child: buildPlayerSubPanel(
                                        activeView: activeView,
                                        videoId: videoId,
                                        position: playerState.position,
                                      ),
                                    )
                                    : insightsOpen
                                    ? const SingleChildScrollView(
                                      key: ValueKey('insights'),
                                      child: PlayerInsightsCard(),
                                    )
                                    : const SizedBox.expand(
                                      key: ValueKey('empty'),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TvFocusable(
                          enabled: !blocked,
                          onDirection: (direction) {
                            if (blocked) return false;
                            if (direction == TraversalDirection.left) {
                              notifier.seekBy(const Duration(seconds: -10));
                              return true;
                            }
                            if (direction == TraversalDirection.right) {
                              notifier.seekBy(const Duration(seconds: 10));
                              return true;
                            }
                            return false;
                          },
                          child: buildProgressBar(context, ref, playerState),
                        ),
                        const SizedBox(height: 16),
                        _TransportRow(
                          playerState: playerState,
                          isEpisode: isEpisode,
                          blocked: blocked,
                          notifier: notifier,
                        ),
                        const SizedBox(height: 16),
                        _ActionsRow(
                          activeView: activeView,
                          isEpisode: isEpisode,
                          isVideo: isVideo,
                          showRelated: showRelated,
                          showPlayerAsk: showPlayerAsk,
                          insightsOpen: insightsOpen,
                          isOffline: isOffline,
                          eqEnabled: eqEnabled,
                          hasTimer: hasTimer,
                          onToggleSubView: _toggleSubView,
                          onInsights: () {
                            if (insightsOpen) {
                              ref
                                  .read(playerInsightsProvider.notifier)
                                  .dismiss();
                            } else {
                              PlayerInsightsOverlay.open(context, ref);
                            }
                          },
                          onEqualizer: () => EqualizerPanel.show(context),
                          onTimer:
                              () => showPlayerTimerDialog(context, notifier),
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.playerState,
    required this.isEpisode,
    required this.blocked,
    required this.notifier,
  });

  final PlayerState playerState;
  final bool isEpisode;
  final bool blocked;
  final PlayerNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isEpisode)
          TvFocusable(
            enabled: !blocked,
            onSelect: () => notifier.seekBy(const Duration(seconds: -15)),
            child: _LabelChip(label: '−15', tooltip: l10n.seekBack15),
          )
        else
          TvFocusable(
            onSelect: () => notifier.toggleShuffle(),
            child: _TransportIcon(
              LucideIcons.shuffle,
              active: playerState.shuffleMode == AudioServiceShuffleMode.all,
            ),
          ),
        const SizedBox(width: 16),
        TvFocusable(
          enabled: !blocked,
          onSelect: () => notifier.skipToPrevious(),
          child: const _TransportIcon(LucideIcons.skipBack),
        ),
        const SizedBox(width: 16),
        TvFocusable(
          key: const Key('tv_np_play'),
          autofocus: true,
          enabled: !blocked,
          onSelect: () => notifier.togglePlayPause(),
          child: _TransportIcon(
            playerState.isPlaying ? LucideIcons.pause : LucideIcons.play,
            large: true,
          ),
        ),
        const SizedBox(width: 16),
        TvFocusable(
          enabled: !blocked,
          onSelect: () => notifier.skipToNext(),
          child: const _TransportIcon(LucideIcons.skipForward),
        ),
        const SizedBox(width: 16),
        if (isEpisode)
          TvFocusable(
            enabled: !blocked,
            onSelect: () => notifier.seekBy(const Duration(seconds: 30)),
            child: _LabelChip(label: '+30', tooltip: l10n.seekForward30),
          )
        else
          TvFocusable(
            onSelect: () => notifier.cycleRepeatMode(),
            child: _TransportIcon(
              playerState.repeatMode == AudioServiceRepeatMode.one
                  ? LucideIcons.repeat1
                  : LucideIcons.repeat,
              active: playerState.repeatMode != AudioServiceRepeatMode.none,
            ),
          ),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.activeView,
    required this.isEpisode,
    required this.isVideo,
    required this.showRelated,
    required this.showPlayerAsk,
    required this.insightsOpen,
    required this.isOffline,
    required this.eqEnabled,
    required this.hasTimer,
    required this.onToggleSubView,
    required this.onInsights,
    required this.onEqualizer,
    required this.onTimer,
    required this.onClose,
  });

  final PlayerSubView activeView;
  final bool isEpisode;
  final bool isVideo;
  final bool showRelated;
  final bool showPlayerAsk;
  final bool insightsOpen;
  final bool isOffline;
  final bool eqEnabled;
  final bool hasTimer;
  final ValueChanged<PlayerSubView> onToggleSubView;
  final VoidCallback onInsights;
  final VoidCallback onEqualizer;
  final VoidCallback onTimer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        if (!isVideo && !isEpisode)
          TvFocusable(
            onSelect: () => onToggleSubView(PlayerSubView.lyrics),
            child: _TransportIcon(
              LucideIcons.micVocal,
              active: activeView == PlayerSubView.lyrics,
            ),
          ),
        if (isEpisode)
          TvFocusable(
            onSelect: () => onToggleSubView(PlayerSubView.notes),
            child: _TransportIcon(
              LucideIcons.fileText,
              active: activeView == PlayerSubView.notes,
            ),
          ),
        if (showPlayerAsk)
          TvFocusable(
            onSelect: onInsights,
            child: _TransportIcon(LucideIcons.sparkles, active: insightsOpen),
          ),
        if (showRelated)
          TvFocusable(
            enabled: !isOffline,
            onSelect:
                isOffline ? null : () => onToggleSubView(PlayerSubView.related),
            child: _TransportIcon(
              LucideIcons.orbit,
              active: activeView == PlayerSubView.related,
              dimmed: isOffline,
            ),
          ),
        TvFocusable(
          key: const Key('tv_np_queue'),
          onSelect: () => onToggleSubView(PlayerSubView.queue),
          child: _TransportIcon(
            LucideIcons.listMusic,
            active: activeView == PlayerSubView.queue,
          ),
        ),
        TvFocusable(
          onSelect: onEqualizer,
          child: _TransportIcon(LucideIcons.sliders, active: eqEnabled),
        ),
        TvFocusable(
          onSelect: onTimer,
          child: _TransportIcon(LucideIcons.timer, active: hasTimer),
        ),
        TvFocusable(
          onSelect: onClose,
          child: const _TransportIcon(LucideIcons.chevronDown),
        ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  final MediaItem song;

  const _Artwork({required this.song});

  @override
  Widget build(BuildContext context) {
    final artUrl = song.artUri?.toString();
    final size = TvMetrics.nowPlayingArtSize;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: size,
        height: size,
        child:
            artUrl != null
                ? CachedNetworkImage(imageUrl: artUrl, fit: BoxFit.cover)
                : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: const Icon(LucideIcons.music, size: 72),
                ),
      ),
    );
  }
}

class _TransportIcon extends StatelessWidget {
  final IconData icon;
  final bool large;
  final bool active;
  final bool dimmed;

  const _TransportIcon(
    this.icon, {
    this.large = false,
    this.active = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base =
        active
            ? colorScheme.primary
            : (large ? colorScheme.onPrimaryContainer : colorScheme.onSurface);
    return Opacity(
      opacity: dimmed ? 0.38 : 1,
      child: Container(
        width: large ? 72 : 56,
        height: large ? 72 : 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              large
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: large ? 36 : 26, color: base),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, required this.tooltip});

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
