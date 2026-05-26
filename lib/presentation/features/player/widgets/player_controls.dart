import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../providers/player_provider.dart';
import '../../../../l10n/app_localizations.dart';

class PlayerControls extends ConsumerWidget {
  final Color? iconColor;

  const PlayerControls({super.key, this.iconColor});

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
                : iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: notifier.toggleShuffle,
      tooltip:
          isShuffle
              ? AppLocalizations.of(context)!.shuffleOn
              : AppLocalizations.of(context)!.shuffleOff,
    );
  }

  Widget _buildSkipButton(
    BuildContext context,
    bool isNext,
    PlayerNotifier notifier, {
    bool disabled = false,
  }) {
    return IconButton(
      icon: Icon(
        isNext ? Icons.skip_next : Icons.skip_previous,
        size: 32,
        color: iconColor,
      ),
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
    final primaryColor = iconColor ?? Theme.of(context).colorScheme.primary;
    final onPrimaryColor =
        iconColor != null
            ? (ThemeData.estimateBrightnessForColor(iconColor!) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black)
            : Theme.of(context).colorScheme.onPrimary;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSwitching ? primaryColor.withAlpha(128) : primaryColor,
      ),
      child: IconButton(
        icon: Icon(
          state.isPlaying ? Icons.pause : Icons.play_arrow,
          color: onPrimaryColor,
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
        tooltip = AppLocalizations.of(context)!.repeatAll;
        color = Theme.of(context).colorScheme.primary;
        break;
      case AudioServiceRepeatMode.one:
        icon = Icons.repeat_one;
        tooltip = AppLocalizations.of(context)!.repeatOne;
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        icon = Icons.repeat;
        tooltip = AppLocalizations.of(context)!.repeatOff;
        color = iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: notifier.cycleRepeatMode,
      tooltip: tooltip,
    );
  }
}
