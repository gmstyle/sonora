import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_insights_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_insights_panel.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/progress_bar_widget.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/top_bar.dart';
import '../widgets/artwork.dart';
import '../widgets/up_next_companion.dart';
import '../widgets/wide_context_panels.dart';

/// Neighbor covers sit beside the current one, smaller, with a clear gap.
const _neighborScale = 0.62;
const _neighborGap = 0.22;

double get _artworkStageFactor => 1 + 2 * (_neighborScale + _neighborGap);

/// Queue drawer width and hero cap for the wide full player.
///
/// Below [kWideContentBreakpoint] the drawer is narrower and the disc caps
/// earlier, so the canvas stays readable beside the queue.
({double queue, double insights, double artMax}) widePlayerFrame(double width) {
  final roomy = width >= kWideContentBreakpoint;
  return (
    queue: roomy ? 380.0 : 320.0,
    insights: roomy ? 560.0 : 480.0,
    artMax: roomy ? 520.0 : 420.0,
  );
}

/// Tablet drawer widths. The queue stays narrow. Curiosities take half the
/// window, capped so the disc remains visible.
({double queue, double insights, double artMax}) tabletPlayerFrame(
  double width,
) {
  return (
    queue: 300.0,
    insights: (width * 0.5).clamp(320.0, 420.0),
    artMax: width < 900 ? 340.0 : 400.0,
  );
}

/// Wide full player in the shape of a desktop now-playing screen.
///
/// The canvas is a scroll: the current disc fills the first screen, with the
/// previous and next covers set apart on either side. Below that, artist and album
/// share the left column and related is the right one. Lyrics and notes
/// replace that scroll. Queue and curiosities share one right-hand card that
/// slides in from the edge. Track info, transport, and the action row sit in
/// the bottom bar, each in its own third.
class WidePlayerLayout extends ConsumerWidget {
  const WidePlayerLayout({
    super.key,
    required this.artworkKey,
    required this.currentSong,
    required this.videoId,
    required this.artUrl,
    required this.albumName,
    required this.playerState,
    required this.playerNotifier,
    required this.hasSleepTimer,
    required this.availHeight,
    required this.availWidth,
    required this.bottomInset,
    required this.activeView,
    this.tablet = false,
  });

  final GlobalKey artworkKey;
  final MediaItem currentSong;
  final String videoId;
  final String? artUrl;
  final String? albumName;
  final PlayerState playerState;
  final PlayerNotifier playerNotifier;
  final bool hasSleepTimer;
  final double availHeight;
  final double availWidth;
  final double bottomInset;
  final PlayerSubView activeView;

  /// Same page as wide, with neighbor covers, a single content column, and
  /// narrower drawers.
  final bool tablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tight = availHeight < 720;
    final drawer = ref.watch(playerQueueDrawerProvider);
    final queueOpen = wideQueueOpen(drawer: drawer, view: activeView);
    final canvas = wideCanvasView(activeView);
    final insightsOpen = ref.watch(playerInsightsProvider).isOpen;
    final frame = tablet
        ? tabletPlayerFrame(availWidth)
        : widePlayerFrame(availWidth);

    ref.listen(playerSubViewProvider, (prev, next) {
      if (next != PlayerSubView.queue) return;
      ref.read(playerQueueDrawerProvider.notifier).set(true);
      ref.read(playerSubViewProvider.notifier).set(PlayerSubView.none);
    });
    ref.listen(playerInsightsProvider.select((state) => state.isOpen), (
      prev,
      open,
    ) {
      if (open) ref.read(playerQueueDrawerProvider.notifier).set(false);
    });
    ref.listen(playerQueueDrawerProvider, (prev, open) {
      if (open) ref.read(playerInsightsProvider.notifier).dismiss();
    });
    if (activeView == PlayerSubView.queue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(playerQueueDrawerProvider.notifier).set(true);
        if (ref.read(playerSubViewProvider) == PlayerSubView.queue) {
          ref.read(playerSubViewProvider.notifier).set(PlayerSubView.none);
        }
      });
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, tight ? 4 : 8, 8, 0),
            child: TopBar(currentSong: currentSong, albumName: albumName),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _canvas(
                    context,
                    ref,
                    canvas: canvas,
                    artMax: frame.artMax,
                    neighbors: true,
                    stackContext: tablet,
                  ),
                ),
                _PlayerSidePanel(
                  open: queueOpen && !insightsOpen,
                  width: frame.queue,
                  child: const _QueueDrawer(),
                ),
                _PlayerSidePanel(
                  open: insightsOpen,
                  width: frame.insights,
                  child: const _InsightsDrawer(),
                ),
              ],
            ),
          ),
          _BottomBar(
            currentSong: currentSong,
            videoId: videoId,
            artUrl: artUrl,
            playerState: playerState,
            playerNotifier: playerNotifier,
            hasSleepTimer: hasSleepTimer,
            activeView: activeView,
            compactActions: tablet,
          ),
        ],
      ),
    );
  }

  Widget _canvas(
    BuildContext context,
    WidgetRef ref, {
    required PlayerSubView canvas,
    required double artMax,
    required bool neighbors,
    required bool stackContext,
  }) {
    if (canvas != PlayerSubView.none) {
      return buildPlayerSubPanel(
        activeView: canvas,
        videoId: videoId,
        position: playerState.position,
      );
    }
    final offline = ref.watch(isOfflineProvider);
    final track = QueueTrack.fromMediaItem(currentSong);
    final catalog = !offline && !track.isEpisode;
    return _NowPlayingPage(
      artworkKey: artworkKey,
      artUrl: artUrl,
      videoId: videoId,
      playerState: playerState,
      artMax: artMax,
      artistId: catalog ? track.artistId : null,
      albumId: catalog ? track.albumId : null,
      showRelated: !offline,
      neighbors: neighbors,
      stackContext: stackContext,
    );
  }
}

class _NowPlayingPage extends ConsumerWidget {
  const _NowPlayingPage({
    required this.artworkKey,
    required this.artUrl,
    required this.videoId,
    required this.playerState,
    required this.artMax,
    required this.artistId,
    required this.albumId,
    required this.showRelated,
    required this.neighbors,
    required this.stackContext,
  });

  final GlobalKey artworkKey;
  final String? artUrl;
  final String videoId;
  final PlayerState playerState;
  final double artMax;
  final String? artistId;
  final String? albumId;
  final bool showRelated;
  final bool neighbors;
  final bool stackContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final pad = neighbors ? 48.0 : 32.0;
        final inner = max(72.0, constraints.maxWidth - pad * 2);
        final side =
            (neighbors
                    ? min(inner / _artworkStageFactor, viewport * 0.62)
                    : min(inner * 0.72, viewport * 0.62))
                .clamp(neighbors ? 72.0 : 120.0, artMax);
        final blocked = playerState.isBlocked;
        final previous = _previousTrack(playerState);
        final upcoming = upcomingTracks(playerState, limit: 1);
        final next = upcoming.isEmpty ? null : upcoming.first.item;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: viewport,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: neighbors
                              ? _ArtworkStage(
                                  artworkKey: artworkKey,
                                  artUrl: artUrl,
                                  videoId: videoId,
                                  size: side,
                                  isSwitching: playerState.isSwitching,
                                  previous: previous,
                                  next: next,
                                  onPrevious: blocked
                                      ? null
                                      : () => ref
                                            .read(playerStateProvider.notifier)
                                            .skipToPrevious(),
                                  onNext: blocked
                                      ? null
                                      : () => ref
                                            .read(playerStateProvider.notifier)
                                            .skipToNext(),
                                )
                              : Artwork(
                                  key: artworkKey,
                                  artUrl: artUrl,
                                  size: side,
                                  minSize: min(side, 120),
                                  videoId: videoId,
                                  isSwitching: playerState.isSwitching,
                                ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          artistId != null && artistId!.isNotEmpty
                              ? l10n.aboutTheArtist
                              : (showRelated ? l10n.related : l10n.upNext),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: WideContextPanels(
                videoId: videoId,
                artistId: artistId,
                albumId: albumId,
                showRelated: showRelated,
                stacked: stackContext,
              ),
            ),
          ],
        );
      },
    );
  }
}

MediaItem? _previousTrack(PlayerState state) {
  final index = state.currentIndex - 1;
  if (index < 0 || index >= state.queue.length) return null;
  return state.queue[index];
}

/// Current cover, with the previous and next covers peeking behind it.
class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({
    required this.artworkKey,
    required this.artUrl,
    required this.videoId,
    required this.size,
    required this.isSwitching,
    required this.previous,
    required this.next,
    required this.onPrevious,
    required this.onNext,
  });

  final GlobalKey artworkKey;
  final String? artUrl;
  final String videoId;
  final double size;
  final bool isSwitching;
  final MediaItem? previous;
  final MediaItem? next;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final peek = size * _neighborScale;
    final wing = size * (_neighborScale + _neighborGap);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: size + wing * 2,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (previous != null)
            Positioned(
              left: 0,
              top: (size - peek) / 2,
              child: _NeighborArtwork(
                item: previous!,
                size: peek,
                tooltip: l10n.previousTrack,
                onTap: onPrevious,
              ),
            ),
          if (next != null)
            Positioned(
              right: 0,
              top: (size - peek) / 2,
              child: _NeighborArtwork(
                item: next!,
                size: peek,
                tooltip: l10n.nextTrack,
                onTap: onNext,
              ),
            ),
          Artwork(
            key: artworkKey,
            artUrl: artUrl,
            size: size,
            minSize: min(size, 72),
            videoId: videoId,
            isSwitching: isSwitching,
          ),
        ],
      ),
    );
  }
}

class _NeighborArtwork extends StatelessWidget {
  const _NeighborArtwork({
    required this.item,
    required this.size,
    required this.tooltip,
    required this.onTap,
  });

  final MediaItem item;
  final double size;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pc = PlayerColors.of(context);
    final art = item.artUri?.toString();
    return Opacity(
      opacity: 0.72,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: size,
              height: size,
              child: art == null
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Icon(LucideIcons.music, color: pc.iconSecondary),
                    )
                  : CachedNetworkImage(
                      imageUrl: art,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          Icon(LucideIcons.music, color: pc.iconSecondary),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right-hand player panel. The slot width and the card slide together.
class _PlayerSidePanel extends ConsumerStatefulWidget {
  const _PlayerSidePanel({
    required this.open,
    required this.width,
    required this.child,
  });

  final bool open;
  final double width;
  final Widget child;

  @override
  ConsumerState<_PlayerSidePanel> createState() => _PlayerSidePanelState();
}

class _PlayerSidePanelState extends ConsumerState<_PlayerSidePanel>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 250);

  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.open ? 1 : 0,
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _PlayerSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) _sync();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    final reduce = ref.read(settingsProvider).reduceEffects;
    _controller.duration = reduce ? Duration.zero : _duration;
    if (widget.open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.reduceEffects), (prev, next) {
      _sync();
    });
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        return ClipRect(
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: t,
            child: FractionalTranslation(
              translation: Offset(1 - t, 0),
              child: child,
            ),
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return SizedBox(
            width: widget.width,
            height: height.isFinite ? height : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: PlayerSurfaceCard(
                padding: EdgeInsets.zero,
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QueueDrawer extends ConsumerWidget {
  const _QueueDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(l10n.queue, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                tooltip: l10n.close,
                onPressed: () {
                  ref.read(playerQueueDrawerProvider.notifier).set(false);
                  if (ref.read(playerSubViewProvider) == PlayerSubView.queue) {
                    ref
                        .read(playerSubViewProvider.notifier)
                        .set(PlayerSubView.none);
                  }
                },
                icon: Icon(
                  LucideIcons.x,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: QueueSheet()),
      ],
    );
  }
}

class _InsightsDrawer extends StatelessWidget {
  const _InsightsDrawer();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(child: PlayerInsightsCard());
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.currentSong,
    required this.videoId,
    required this.artUrl,
    required this.playerState,
    required this.playerNotifier,
    required this.hasSleepTimer,
    required this.activeView,
    required this.compactActions,
  });

  final MediaItem currentSong;
  final String videoId;
  final String? artUrl;
  final PlayerState playerState;
  final PlayerNotifier playerNotifier;
  final bool hasSleepTimer;
  final PlayerSubView activeView;
  final bool compactActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pc = PlayerColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Artwork(
                        artUrl: artUrl,
                        size: 56,
                        minSize: 48,
                        videoId: videoId,
                        isSwitching: playerState.isSwitching,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pc.titlePrimary,
                            ),
                          ),
                          Text(
                            currentSong.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pc.subtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    buildLikeButton(context, ref, currentSong),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ProgressBarWidget(
                      position: playerState.position,
                      duration: playerState.duration,
                      disabled: playerState.isRestoring,
                      isPlaying: playerState.isPlaying,
                      density: ProgressBarDensity.comfortable,
                      onSeek: (pos) =>
                          ref.read(playerStateProvider.notifier).seek(pos),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: const PlayerControls(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: buildBottomActionsRow(
                  context,
                  ref,
                  hasSleepTimer,
                  playerNotifier,
                  activeView,
                  queueOpensDrawer: true,
                  showRelatedToggle: false,
                  compactActions: compactActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
