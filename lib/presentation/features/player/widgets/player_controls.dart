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

    final hasSleepTimer = playerState.sleepTimerRemaining != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildShuffleButton(context, playerState, notifier),
          const SizedBox(width: 8),
          _buildSkipButton(context, false, notifier),
          const SizedBox(width: 16),
          _buildPlayPauseButton(context, playerState, notifier),
          const SizedBox(width: 16),
          _buildSkipButton(context, true, notifier),
          const SizedBox(width: 8),
          _buildRepeatButton(context, playerState, notifier),
          const SizedBox(width: 8),
          _buildTimerButton(context, hasSleepTimer, notifier),
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
    PlayerNotifier notifier,
  ) {
    return IconButton(
      icon: Icon(isNext ? Icons.skip_next : Icons.skip_previous, size: 32),
      onPressed: isNext ? notifier.skipToNext : notifier.skipToPrevious,
    );
  }

  Widget _buildPlayPauseButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: IconButton(
        icon: Icon(
          state.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
        onPressed: notifier.togglePlayPause,
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

  Widget _buildTimerButton(
    BuildContext context,
    bool hasTimer,
    PlayerNotifier notifier,
  ) {
    return IconButton(
      icon: Icon(
        Icons.timer,
        size: 22,
        color:
            hasTimer
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => _showTimerDialog(context, notifier),
      tooltip: hasTimer ? 'Sleep timer active' : 'Sleep timer',
    );
  }

  void _showTimerDialog(BuildContext context, PlayerNotifier notifier) {
    final options = [5, 10, 15, 30, 45, 60];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sleep Timer',
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
                  'Cancel Timer',
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
