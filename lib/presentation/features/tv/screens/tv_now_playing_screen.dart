import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/screen_keep_awake.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
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

/// Full-bleed now playing with optional karaoke lyrics stage.
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(TvMetrics.contentPadding),
        child: Row(
          children: [
            Expanded(
              flex: _lyrics ? 4 : 5,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Chrome below the artwork: back, gaps, title, artist, seek, controls.
                  const reserved = 220.0;
                  final artBudget = (constraints.maxHeight - reserved).clamp(
                    120.0,
                    _lyrics ? 280.0 : 420.0,
                  );
                  final artSize = artBudget
                      .clamp(120.0, constraints.maxWidth)
                      .toDouble();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TvFocusable(
                        onSelect: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(28),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(LucideIcons.chevronDown, size: 28),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: ThumbnailWidget(
                            imageUrl: song.artUri?.toString(),
                            size: artSize,
                            shape: ThumbnailShape.rounded,
                            borderRadius: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TvSeekBar(player: player, notifier: notifier),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TvFocusable(
                            onSelect: () => notifier.skipToPrevious(),
                            child: const Icon(LucideIcons.skipBack, size: 32),
                          ),
                          const SizedBox(width: 16),
                          TvFocusable(
                            onSelect: () => notifier.togglePlayPause(),
                            child: Icon(
                              player.isPlaying
                                  ? LucideIcons.pause
                                  : LucideIcons.play,
                              size: 40,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TvFocusable(
                            onSelect: () => notifier.skipToNext(),
                            child: const Icon(
                              LucideIcons.skipForward,
                              size: 32,
                            ),
                          ),
                          const Spacer(),
                          TvFocusable(
                            onSelect: () {
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
                            child: Icon(
                              liked != null
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 28,
                              color: liked != null
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TvFocusable(
                            onSelect: () => _setLyrics(!_lyrics),
                            borderRadius: BorderRadius.circular(28),
                            child: FilledButton.tonalIcon(
                              onPressed: () => _setLyrics(!_lyrics),
                              icon: Icon(
                                _lyrics ? LucideIcons.disc3 : LucideIcons.mic2,
                              ),
                              label: Text(_lyrics ? l10n.queue : l10n.lyrics),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_lyrics) ...[
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
          ],
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
    // Up / Down / Select: let focus traversal and parent handlers run.
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
            color: _focused ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
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
                color: colorScheme.primary,
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
