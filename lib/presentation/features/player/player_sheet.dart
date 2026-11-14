import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/player_colors.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import 'full_player_content.dart';
import 'mini_player_content.dart';

/// Full-width mini-player shelf used by [TabletShell] and [WideShell].
///
/// Sits under the navigation column and the content pane. Mobile shells use
/// [PlayerSheetMobile] as a card above the navigation bar.
class PlayerSheet extends ConsumerWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fill = isDark
        ? SonoraPulseTokens.darkSurfaceVariant.withValues(
            alpha: reduceEffects ? 1 : 0.92,
          )
        : cs.surfaceContainerLowest.withValues(alpha: reduceEffects ? 1 : 0.94);

    final miniPlayerChild = MiniPlayerContent(
      currentSong: currentSong,
      playerState: playerState,
      onTap: () => openFullPlayer(context),
      onPlayPause: () =>
          ref.read(playerStateProvider.notifier).togglePlayPause(),
      onSkipNext: () => ref.read(playerStateProvider.notifier).skipToNext(),
      onSkipPrevious: () =>
          ref.read(playerStateProvider.notifier).skipToPrevious(),
      onOpenLyrics: () =>
          openFullPlayer(context, subView: PlayerSubView.lyrics),
      onOpenQueue: () => openFullPlayer(context, subView: PlayerSubView.queue),
      onSeek: (pos) => ref.read(playerStateProvider.notifier).seek(pos),
    );

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          top: BorderSide(
            color: isDark
                ? SonoraPulseTokens.darkBorder.withValues(alpha: 0.6)
                : cs.outlineVariant,
          ),
        ),
        boxShadow: reduceEffects
            ? null
            : [
                BoxShadow(
                  color:
                      (PlayerColors.maybeOf(context)?.accent ??
                              SonoraPulseTokens.gradientStart)
                          .withValues(alpha: isDark ? 0.08 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SizedBox(
        height: kMiniPlayerShelfHeight,
        width: double.infinity,
        child: miniPlayerChild,
      ),
    );

    if (reduceEffects) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: bar,
      ),
    );
  }
}
