import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../providers/player_provider.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../providers/settings_provider.dart';
import 'animated_play_pause_icon.dart';

class PlayerControls extends ConsumerWidget {
  final Color? iconColor;

  const PlayerControls({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final glow = !ref.watch(settingsProvider.select((s) => s.reduceEffects));
    final current = playerState.currentSong;
    final isEpisode =
        current != null && QueueTrack.fromMediaItem(current).isEpisode;

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
                  if (isEpisode)
                    _buildSeekButton(
                      context,
                      notifier,
                      offset: const Duration(seconds: -15),
                      label: '−15',
                      tooltip: AppLocalizations.of(context)!.seekBack15,
                      disabled: playerState.isBlocked,
                    )
                  else
                    _buildShuffleButton(context, playerState, notifier),
                  _buildSkipButton(
                    context,
                    false,
                    notifier,
                    disabled: playerState.isBlocked,
                  ),
                  _buildPlayPauseButton(
                    context,
                    playerState,
                    notifier,
                    glow: glow,
                  ),
                  _buildSkipButton(
                    context,
                    true,
                    notifier,
                    disabled: playerState.isBlocked,
                  ),
                  if (isEpisode)
                    _buildSeekButton(
                      context,
                      notifier,
                      offset: const Duration(seconds: 30),
                      label: '+30',
                      tooltip: AppLocalizations.of(context)!.seekForward30,
                      disabled: playerState.isBlocked,
                    )
                  else
                    _buildRepeatButton(context, playerState, notifier),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeekButton(
    BuildContext context,
    PlayerNotifier notifier, {
    required Duration offset,
    required String label,
    required String tooltip,
    bool disabled = false,
  }) {
    return IconButton(
      icon: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      onPressed:
          disabled
              ? null
              : () {
                HapticFeedback.lightImpact();
                notifier.seekBy(offset);
              },
      tooltip: tooltip,
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
                  ? _pulseAccent(context)
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
    PlayerNotifier notifier, {
    required bool glow,
  }) {
    final isBlocked = state.isBlocked;
    return Container(
      decoration: SonoraPulseTokens.playControlDecoration(
        enabled: !isBlocked,
        glow: glow,
      ),
      child: IconButton(
        icon: AnimatedPlayPauseIcon(
          isPlaying: state.isPlaying,
          isLoading: state.isRestoring,
          color: SonoraPulseTokens.onPrimary,
          size: 32,
        ),
        onPressed:
            isBlocked
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
        color = _pulseAccent(context);
        break;
      case AudioServiceRepeatMode.one:
        icon = LucideIcons.repeat1;
        tooltip = AppLocalizations.of(context)!.repeatOne;
        color = _pulseAccent(context);
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

  Color _pulseAccent(BuildContext context) =>
      PlayerColors.maybeOf(context)?.accent ??
      SonoraPulseTokens.primaryContainer;
}
