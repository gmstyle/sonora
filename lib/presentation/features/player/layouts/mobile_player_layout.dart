import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/player_insights_provider.dart';
import '../../../providers/player_provider.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_insights_panel.dart';
import '../widgets/player_shared_widgets.dart';
import '../widgets/top_bar.dart';
import '../widgets/artwork.dart';
import '../widgets/up_next_companion.dart';

/// Compact full player.
///
/// Portrait keeps one column: the center shows the disc and the up-next card
/// together, and lyrics, queue, related, notes, and insights replace that
/// slot. Title, seek, transport, and actions stay underneath.
///
/// Landscape (width greater than height) splits the same player. The disc or
/// the active view fills the left side. Title, seek, transport, and the
/// compact actions sit on the right. Up Next stays on the portrait column.
class MobilePlayerLayout extends ConsumerWidget {
  const MobilePlayerLayout({
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

  bool get _landscape => availWidth > availHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_landscape) return _landscapeBody(context, ref);
    return _portraitBody(context, ref);
  }

  Widget _portraitBody(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insightsOpen = ref.watch(playerInsightsProvider).isOpen;
    final panelOpen = activeView != PlayerSubView.none;
    final tight = availHeight < 600;
    final gap = tight ? 8.0 : 16.0;

    return SafeArea(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: EdgeInsets.only(top: tight ? 4 : 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TopBar(currentSong: currentSong, albumName: albumName),
              SizedBox(height: tight ? 8 : 16),
              Expanded(
                child: panelOpen
                    ? buildPlayerSubPanel(
                        activeView: activeView,
                        videoId: videoId,
                        position: playerState.position,
                      )
                    : insightsOpen
                    ? const SingleChildScrollView(child: PlayerInsightsCard())
                    : _center(),
              ),
              SizedBox(height: gap),
              buildTrackInfoAndLikeRow(context, ref, currentSong),
              SizedBox(height: gap),
              buildProgressBar(context, ref, playerState),
              SizedBox(height: gap),
              const PlayerControls(),
              const SizedBox(height: 8),
              buildBottomActionsRow(
                context,
                ref,
                hasSleepTimer,
                playerNotifier,
                activeView,
                isMobile: true,
              ),
              SizedBox(height: tight ? 8 : 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Landscape phone: stage on the left, transport on the right.
  Widget _landscapeBody(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insightsOpen = ref.watch(playerInsightsProvider).isOpen;
    final panelOpen = activeView != PlayerSubView.none;
    final transportWidth = _landscapeTransportWidth(availWidth);

    return SafeArea(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _stage(panelOpen, insightsOpen)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: transportWidth,
                      child: _transportColumn(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Right-hand chrome. Capped at 320 so the stage keeps the width.
  double _landscapeTransportWidth(double width) {
    final preferred = width * 0.42;
    if (preferred < 220) return preferred.clamp(160.0, 220.0);
    if (preferred > 320) return 320;
    return preferred;
  }

  Widget _stage(bool panelOpen, bool insightsOpen) {
    if (panelOpen) {
      return buildPlayerSubPanel(
        activeView: activeView,
        videoId: videoId,
        position: playerState.position,
      );
    }
    if (insightsOpen) {
      return const SingleChildScrollView(child: PlayerInsightsCard());
    }
    return _artwork();
  }

  Widget _transportColumn(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(currentSong: currentSong, albumName: albumName),
        const SizedBox(height: 8),
        buildTrackInfoAndLikeRow(context, ref, currentSong),
        const SizedBox(height: 8),
        buildProgressBar(context, ref, playerState),
        const SizedBox(height: 8),
        const PlayerControls(),
        const SizedBox(height: 4),
        buildBottomActionsRow(
          context,
          ref,
          hasSleepTimer,
          playerNotifier,
          activeView,
          isMobile: true,
        ),
      ],
    );
  }

  /// Disc above the up-next card. The disc takes the leftover height.
  Widget _center() {
    return Column(
      children: [
        Expanded(child: _artwork()),
        const SizedBox(height: 12),
        const UpNextCompanion(
          maxItems: 1,
          showSleepBadge: true,
          shrinkWrap: true,
        ),
      ],
    );
  }

  Widget _artwork() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(
          constraints.maxWidth,
          constraints.maxHeight,
        ).clamp(72.0, 360.0);
        return Center(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (playerState.isBlocked || details.primaryVelocity == null) {
                return;
              }
              if (details.primaryVelocity! < -250) {
                HapticFeedback.lightImpact();
                playerNotifier.skipToNext();
              } else if (details.primaryVelocity! > 250) {
                HapticFeedback.lightImpact();
                playerNotifier.skipToPrevious();
              }
            },
            child: Artwork(
              key: artworkKey,
              artUrl: artUrl,
              size: side,
              minSize: min(side, 72),
              videoId: videoId,
              isSwitching: playerState.isSwitching,
            ),
          ),
        );
      },
    );
  }
}
