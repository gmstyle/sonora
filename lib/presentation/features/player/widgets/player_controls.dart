import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../providers/player_provider.dart';
import '../../../../l10n/app_localizations.dart';
import 'animated_play_pause_icon.dart';

class PlayerControls extends ConsumerWidget {
  final Color? iconColor;

  const PlayerControls({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
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
            ),
          );
        },
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
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder:
            (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
        child: Icon(
          LucideIcons.shuffle,
          key: ValueKey(isShuffle),
          color:
              isShuffle
                  ? Theme.of(context).colorScheme.primary
                  : iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        notifier.toggleShuffle();
      },
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
        isNext ? LucideIcons.skipForward : LucideIcons.skipBack,
        size: 32,
        color: iconColor,
      ),
      onPressed:
          disabled
              ? null
              : () {
                HapticFeedback.lightImpact();
                isNext ? notifier.skipToNext() : notifier.skipToPrevious();
              },
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
        icon: AnimatedPlayPauseIcon(
          isPlaying: state.isPlaying,
          color: onPrimaryColor,
          size: 32,
        ),
        onPressed:
            isSwitching
                ? null
                : () {
                  HapticFeedback.lightImpact();
                  notifier.togglePlayPause();
                },
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
        icon = LucideIcons.repeat;
        tooltip = AppLocalizations.of(context)!.repeatAll;
        color = Theme.of(context).colorScheme.primary;
        break;
      case AudioServiceRepeatMode.one:
        icon = LucideIcons.repeat1;
        tooltip = AppLocalizations.of(context)!.repeatOne;
        color = Theme.of(context).colorScheme.primary;
        break;
      default:
        icon = LucideIcons.repeat;
        tooltip = AppLocalizations.of(context)!.repeatOff;
        color = iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder:
            (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
        child: Icon(icon, key: ValueKey('${state.repeatMode}'), color: color),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        notifier.cycleRepeatMode();
      },
      tooltip: tooltip,
    );
  }
}
