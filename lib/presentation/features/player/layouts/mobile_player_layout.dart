import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/top_bar.dart';
import '../widgets/artwork.dart';
import '../widgets/player_bouncing_widget.dart';
import '../../../providers/video_player_provider.dart';

class MobilePlayerLayout extends ConsumerStatefulWidget {
  const MobilePlayerLayout({
    super.key,
    required this.currentSong,
    required this.isVideo,
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
  });

  final MediaItem currentSong;
  final bool isVideo;
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

  @override
  ConsumerState<MobilePlayerLayout> createState() => _MobilePlayerLayoutState();
}

class _MobilePlayerLayoutState extends ConsumerState<MobilePlayerLayout> {
  bool _showDashboard = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final videoState = ref.watch(videoPlayerProvider);
    final isVideoActive =
        widget.isVideo && videoState.isVideoVisible && videoState.isInitialized;

    return SafeArea(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TopBar(
                currentSong: widget.currentSong,
                isVideo: widget.isVideo,
                albumName: widget.albumName,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      widget.activeView == PlayerSubView.none
                          ? Center(
                            key: const ValueKey('none_view'),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap:
                                  isVideoActive && !_showDashboard
                                      ? null
                                      : () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _showDashboard = !_showDashboard;
                                        });
                                      },
                              onHorizontalDragEnd: (details) {
                                if (widget.playerState.isBlocked ||
                                    details.primaryVelocity == null) {
                                  return;
                                }
                                if (details.primaryVelocity! < -250) {
                                  HapticFeedback.lightImpact();
                                  widget.playerNotifier.skipToNext();
                                } else if (details.primaryVelocity! > 250) {
                                  HapticFeedback.lightImpact();
                                  widget.playerNotifier.skipToPrevious();
                                }
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (child, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      if (animation.value <= 0.5) {
                                        return const SizedBox.shrink();
                                      }

                                      final isDashboard =
                                          child?.key ==
                                          const ValueKey('dashboard');
                                      final angle =
                                          isDashboard
                                              ? (animation.value - 1.0) * pi
                                              : (1.0 - animation.value) * pi;

                                      return Transform(
                                        transform:
                                            Matrix4.identity()
                                              ..setEntry(3, 2, 0.0015)
                                              ..rotateY(angle),
                                        alignment: Alignment.center,
                                        child: child,
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    ),
                                child:
                                    _showDashboard
                                        ? PlayerDefaultView(
                                          key: const ValueKey('dashboard'),
                                          tight: widget.availHeight < 600,
                                        )
                                        : Artwork(
                                          key: const ValueKey('artwork'),
                                          artUrl: widget.artUrl,
                                          size: min(
                                            widget.availWidth - 48,
                                            widget.availHeight - 360,
                                          ),
                                          videoId: widget.videoId,
                                          isSwitching:
                                              widget.playerState.isSwitching,
                                          isVideo: widget.isVideo,
                                        ),
                              ),
                            ),
                          )
                          : widget.activeView == PlayerSubView.lyrics
                          ? LyricsView(
                            key: const ValueKey('lyrics'),
                            videoId: widget.videoId,
                            position: widget.playerState.position,
                          )
                          : const QueueSheet(key: ValueKey('queue')),
                ),
              ),
              const SizedBox(height: 32),
              buildTrackInfoAndLikeRow(
                context,
                ref,
                widget.currentSong,
                widget.isVideo,
              ),
              const SizedBox(height: 16),
              buildProgressBar(ref, widget.playerState, widget.videoId),
              const SizedBox(height: 16),
              const PlayerControls(),
              const SizedBox(height: 8),
              buildBottomActionsRow(
                context,
                ref,
                widget.isVideo,
                widget.playerState.sleepTimerRemaining != null,
                widget.playerNotifier,
                widget.activeView,
                isMobile: true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
