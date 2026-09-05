import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import 'mini_player_content.dart';
import 'full_player_content.dart';

/// Mini player overlay used by [TabletShell] and [WideShell] (≥600 px).
///
/// Mobile shells (<600 px) use [PlayerSheetMobile] inside the fused nav dock.
class PlayerSheet extends ConsumerWidget {
  final double bottom;
  const PlayerSheet({super.key, this.bottom = 0.0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final horizontalMargin = isMobile ? 12.0 : 24.0;
    final bottomMargin = isMobile ? bottom + 12.0 : 16.0;

    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );

    final miniPlayerChild = MiniPlayerContent(
      currentSong: currentSong,
      playerState: playerState,
      onTap: () => openFullPlayer(context),
      onPlayPause:
          () => ref.read(playerStateProvider.notifier).togglePlayPause(),
      onSkipNext: () => ref.read(playerStateProvider.notifier).skipToNext(),
      onSkipPrevious:
          () => ref.read(playerStateProvider.notifier).skipToPrevious(),
      onOpenLyrics:
          () => openFullPlayer(context, subView: PlayerSubView.lyrics),
      onOpenQueue: () => openFullPlayer(context, subView: PlayerSubView.queue),
    );

    return Positioned(
      bottom: bottomMargin,
      left: horizontalMargin,
      right: horizontalMargin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child:
              reduceEffects
                  ? miniPlayerChild
                  : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: miniPlayerChild,
                  ),
        ),
      ),
    );
  }
}
