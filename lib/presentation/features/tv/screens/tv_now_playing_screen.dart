import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/player_provider.dart';
import '../../player/full_player_content.dart';
import '../tv_metrics.dart';
import '../widgets/tv_focusable.dart';

/// Opens the TV now-playing overlay (full-bleed transport + queue entry).
void openTvNowPlaying(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: const TvNowPlayingScreen(),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    ),
  );
}

class TvNowPlayingScreen extends ConsumerWidget {
  const TvNowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(playerStateProvider.notifier);

    if (song == null) {
      return Scaffold(
        body: Center(
          child: TvFocusable(
            autofocus: true,
            onSelect: () => Navigator.of(context).maybePop(),
            child: Text(l10n.noConnectionMessage),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TvMetrics.horizontalPadding),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Artwork(song: song),
                    const SizedBox(height: 28),
                    Text(
                      song.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.artist ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TvFocusable(
                          onSelect: () => notifier.skipToPrevious(),
                          child: const _TransportIcon(LucideIcons.skipBack),
                        ),
                        const SizedBox(width: 20),
                        TvFocusable(
                          autofocus: true,
                          onSelect: () => notifier.togglePlayPause(),
                          child: _TransportIcon(
                            playerState.isPlaying
                                ? LucideIcons.pause
                                : LucideIcons.play,
                            large: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        TvFocusable(
                          onSelect: () => notifier.skipToNext(),
                          child: const _TransportIcon(LucideIcons.skipForward),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TvFocusable(
                          onSelect: () => notifier.toggleShuffle(),
                          child: _TransportIcon(
                            LucideIcons.shuffle,
                            active:
                                playerState.shuffleMode ==
                                AudioServiceShuffleMode.all,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TvFocusable(
                          onSelect: () => notifier.cycleRepeatMode(),
                          child: _TransportIcon(
                            LucideIcons.repeat,
                            active:
                                playerState.repeatMode !=
                                AudioServiceRepeatMode.none,
                          ),
                        ),
                        const SizedBox(width: 16),
                        TvFocusable(
                          onSelect:
                              () => openFullPlayer(
                                context,
                                subView: PlayerSubView.queue,
                              ),
                          child: const _TransportIcon(LucideIcons.listMusic),
                        ),
                        const SizedBox(width: 16),
                        TvFocusable(
                          onSelect: () => Navigator.of(context).maybePop(),
                          child: const _TransportIcon(LucideIcons.chevronDown),
                        ),
                      ],
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
}

class _Artwork extends StatelessWidget {
  final MediaItem song;

  const _Artwork({required this.song});

  @override
  Widget build(BuildContext context) {
    final artUrl = song.artUri?.toString();
    final size = TvMetrics.nowPlayingArtSize;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: size,
        height: size,
        child:
            artUrl != null
                ? CachedNetworkImage(imageUrl: artUrl, fit: BoxFit.cover)
                : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: const Icon(LucideIcons.music, size: 72),
                ),
      ),
    );
  }
}

class _TransportIcon extends StatelessWidget {
  final IconData icon;
  final bool large;
  final bool active;

  const _TransportIcon(this.icon, {this.large = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: large ? 72 : 56,
      height: large ? 72 : 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            large
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: large ? 36 : 26,
        color:
            active
                ? colorScheme.primary
                : (large
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface),
      ),
    );
  }
}
