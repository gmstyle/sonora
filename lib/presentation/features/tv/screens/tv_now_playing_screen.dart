import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/screen_keep_awake.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/start_radio_use_case_provider.dart';
import '../../../shared/widgets/context_menu/context_menu_presenter.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../player/widgets/lyrics_view.dart';
import '../tv_metrics.dart';
import '../widgets/tv_focusable.dart';

/// Opens the TV full-bleed now playing stage (not a go_router route).
void openTvNowPlaying(BuildContext context, {bool lyrics = false}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          TvNowPlayingScreen(showLyrics: lyrics),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      fullscreenDialog: true,
    ),
  );
}

/// ATV now-playing stage: centered column; lyrics as optional side panel.
class TvNowPlayingScreen extends ConsumerStatefulWidget {
  final bool showLyrics;

  const TvNowPlayingScreen({super.key, this.showLyrics = false});

  @override
  ConsumerState<TvNowPlayingScreen> createState() => _TvNowPlayingScreenState();
}

class _TvNowPlayingScreenState extends ConsumerState<TvNowPlayingScreen> {
  late bool _lyrics;

  @override
  void initState() {
    super.initState();
    _lyrics = widget.showLyrics;
    if (_lyrics) ScreenKeepAwake.enable();
  }

  @override
  void dispose() {
    ScreenKeepAwake.disable();
    super.dispose();
  }

  void _setLyrics(bool value) {
    if (_lyrics == value) return;
    setState(() => _lyrics = value);
    if (value) {
      ScreenKeepAwake.enable();
    } else {
      ScreenKeepAwake.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerStateProvider);
    final song = player.currentSong;
    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final track = QueueTrack.fromMediaItem(song);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(playerStateProvider.notifier);
    final liked = ref.watch(likedSongProvider(track.videoId)).asData?.value;
    final offline = ref.watch(isOfflineProvider);
    final shuffled = player.shuffleMode == AudioServiceShuffleMode.all;

    Widget stage = _CenteredPlayerStage(
      song: song,
      track: track,
      player: player,
      notifier: notifier,
      liked: liked != null,
      shuffled: shuffled,
      lyrics: _lyrics,
      onToggleLyrics: () => _setLyrics(!_lyrics),
      onLike: () {
        ref
            .read(libraryNotifierProvider.notifier)
            .toggleLikedSong(
              LikedSongModel(
                videoId: track.videoId,
                title: song.title,
                artist: song.artist ?? '',
                artistsJson: track.artistsJson,
                thumbnailUrl: song.artUri?.toString(),
                addedAt: DateTime.now(),
                duration: song.duration?.inSeconds,
                isVideo: track.isVideo,
                isExplicit: track.isExplicit,
              ),
            );
      },
      onRadio: offline
          ? null
          : () => startSongRadio(
              videoId: track.videoId,
              useCase: ref.read(startRadioUseCaseProvider),
              player: notifier,
              feedback: ref.read(actionFeedbackProvider.notifier),
              l10n: l10n,
            ),
      l10n: l10n,
      theme: theme,
      colorScheme: colorScheme,
    );

    if (_lyrics) {
      stage = Row(
        children: [
          Expanded(flex: 5, child: stage),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LyricsView(
                  videoId: track.videoId,
                  position: player.position,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(TvMetrics.contentPadding),
        child: stage,
      ),
    );
  }
}

class _CenteredPlayerStage extends StatelessWidget {
  final MediaItem song;
  final QueueTrack track;
  final PlayerState player;
  final PlayerNotifier notifier;
  final bool liked;
  final bool shuffled;
  final bool lyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onLike;
  final VoidCallback? onRadio;
  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _CenteredPlayerStage({
    required this.song,
    required this.track,
    required this.player,
    required this.notifier,
    required this.liked,
    required this.shuffled,
    required this.lyrics,
    required this.onToggleLyrics,
    required this.onLike,
    required this.onRadio,
    required this.l10n,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TvFocusable(
            onSelect: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(28),
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.chevronDown, size: 28),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 480 || lyrics;
              final playSize = compact ? 52.0 : 68.0;
              final sideSize = compact ? 40.0 : 52.0;
              final smallSize = compact ? 36.0 : 44.0;
              final gap = compact ? 8.0 : 14.0;

              return Column(
                children: [
                  // Artwork fills leftover space — never scrolls.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, artBox) {
                        if (artBox.maxHeight < 72) {
                          return const SizedBox.shrink();
                        }
                        final side = artBox.maxHeight
                            .clamp(72.0, artBox.maxWidth)
                            .toDouble();
                        return Center(
                          child: ThumbnailWidget(
                            imageUrl: song.artUri?.toString(),
                            size: side,
                            shape: ThumbnailShape.rounded,
                            borderRadius: 24,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: gap),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (compact
                                      ? theme.textTheme.titleLarge
                                      : theme.textTheme.headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: gap),
                        _TvSeekBar(player: player, notifier: notifier),
                        SizedBox(height: gap),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CircleControl(
                              icon: LucideIcons.shuffle,
                              selected: shuffled,
                              onSelect: () => notifier.toggleShuffle(),
                              size: smallSize,
                            ),
                            SizedBox(width: compact ? 8 : 14),
                            _CircleControl(
                              icon: LucideIcons.skipBack,
                              onSelect: () => notifier.skipToPrevious(),
                              size: sideSize,
                              tonal: true,
                            ),
                            SizedBox(width: compact ? 8 : 14),
                            _CircleControl(
                              icon: player.isPlaying
                                  ? LucideIcons.pause
                                  : LucideIcons.play,
                              onSelect: () => notifier.togglePlayPause(),
                              size: playSize,
                              filled: true,
                              autofocus: true,
                            ),
                            SizedBox(width: compact ? 8 : 14),
                            _CircleControl(
                              icon: LucideIcons.skipForward,
                              onSelect: () => notifier.skipToNext(),
                              size: sideSize,
                              tonal: true,
                            ),
                            SizedBox(width: compact ? 8 : 14),
                            _CircleControl(
                              icon:
                                  player.repeatMode ==
                                      AudioServiceRepeatMode.one
                                  ? LucideIcons.repeat1
                                  : LucideIcons.repeat,
                              selected:
                                  player.repeatMode !=
                                  AudioServiceRepeatMode.none,
                              onSelect: () => notifier.cycleRepeatMode(),
                              size: smallSize,
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CircleControl(
                              icon: liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              selected: liked,
                              onSelect: onLike,
                              size: smallSize,
                            ),
                            const SizedBox(width: 10),
                            _CircleControl(
                              icon: LucideIcons.radio,
                              onSelect: onRadio,
                              size: smallSize,
                            ),
                            const SizedBox(width: 10),
                            _CircleControl(
                              icon: lyrics
                                  ? LucideIcons.disc3
                                  : LucideIcons.mic2,
                              selected: lyrics,
                              onSelect: onToggleLyrics,
                              size: smallSize,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CircleControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onSelect;
  final double size;
  final bool filled;
  final bool tonal;
  final bool selected;
  final bool autofocus;

  const _CircleControl({
    required this.icon,
    required this.onSelect,
    required this.size,
    this.filled = false,
    this.tonal = false,
    this.selected = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = filled
        ? colorScheme.onSurface
        : tonal
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerLow;
    final fg = filled
        ? colorScheme.surface
        : selected
        ? colorScheme.primary
        : colorScheme.onSurface;

    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      borderRadius: BorderRadius.circular(size / 2),
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onSelect,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.42, color: fg),
          ),
        ),
      ),
    );
  }
}

/// TV seek strip: Left/Right scrub, Up/Down leave focus (no Material [Slider]).
class _TvSeekBar extends StatefulWidget {
  final PlayerState player;
  final PlayerNotifier notifier;

  const _TvSeekBar({required this.player, required this.notifier});

  @override
  State<_TvSeekBar> createState() => _TvSeekBarState();
}

class _TvSeekBarState extends State<_TvSeekBar> {
  final FocusNode _node = FocusNode(debugLabel: 'tvSeekBar');
  bool _focused = false;

  static const _seekStep = Duration(seconds: 10);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.notifier.seekBy(-_seekStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.notifier.seekBy(_seekStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _fmt(Duration d) {
    final total = d.inSeconds.clamp(0, 359999);
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = widget.player.duration;
    final position = widget.player.position;
    final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final progress = (position.inMilliseconds / maxMs).clamp(0.0, 1.0);

    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      onFocusChange: (hasFocus) {
        if (_focused != hasFocus) setState(() => _focused = hasFocus);
      },
      child: AnimatedContainer(
        duration: TvMetrics.drawerAnimDuration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? colorScheme.onSurface : Colors.transparent,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _fmt(position),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt(duration),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
