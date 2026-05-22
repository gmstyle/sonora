import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/player_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildShuffleButton(context, playerState, notifier),
          _buildSkipButton(
            context,
            false,
            notifier,
            disabled: playerState.isSwitching,
          ),
          _buildPlayPauseButton(context, playerState, notifier),
          _buildSkipButton(
            context,
            true,
            notifier,
            disabled: playerState.isSwitching,
          ),
          _buildRepeatButton(context, playerState, notifier),
        ],
      ),
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final isShuffle = state.shuffleMode == AudioServiceShuffleMode.all;
    return IconButton(
      icon: Icon(
        Icons.shuffle,
        color:
            isShuffle
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: notifier.toggleShuffle,
      tooltip: isShuffle ? 'Shuffle on' : 'Shuffle off',
    );
  }

  Widget _buildSkipButton(
    BuildContext context,
    bool isNext,
    PlayerNotifier notifier, {
    bool disabled = false,
  }) {
    return IconButton(
      icon: Icon(isNext ? Icons.skip_next : Icons.skip_previous, size: 32),
      onPressed:
          disabled
              ? null
              : (isNext ? notifier.skipToNext : notifier.skipToPrevious),
    );
  }

  Widget _buildPlayPauseButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final isSwitching = state.isSwitching;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isSwitching
                ? Theme.of(context).colorScheme.primary.withAlpha(128)
                : Theme.of(context).colorScheme.primary,
      ),
      child: IconButton(
        icon: Icon(
          state.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
        onPressed: isSwitching ? null : notifier.togglePlayPause,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    IconData icon;
    String tooltip;
    Color? color;

    switch (state.repeatMode) {
      case AudioServiceRepeatMode.all:
        icon = Icons.repeat;
        tooltip = 'Repeat all';
        color = Theme.of(context).colorScheme.primary;
        break;
      case AudioServiceRepeatMode.one:
        icon = Icons.repeat_one;
        tooltip = 'Repeat one';
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        icon = Icons.repeat;
        tooltip = 'Repeat off';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: notifier.cycleRepeatMode,
      tooltip: tooltip,
    );
  }
}
