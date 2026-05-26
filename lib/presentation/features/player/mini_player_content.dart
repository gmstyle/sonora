import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/shimmer_loading.dart';

class MiniPlayerContent extends StatelessWidget {
  final MediaItem currentSong;
  final PlayerState playerState;
  final bool isVideo;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipNext;

  final VoidCallback? onSkipPrevious;

  const MiniPlayerContent({
    super.key,
    required this.currentSong,
    required this.playerState,
    required this.isVideo,
    this.onTap,
    this.onPlayPause,
    this.onSkipNext,
    this.onSkipPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final isSwitching = playerState.isSwitching;
    final progress =
        playerState.duration.inMilliseconds > 0
            ? playerState.position.inMilliseconds /
                playerState.duration.inMilliseconds
            : 0.0;

    return GestureDetector(
      onTap: isSwitching ? null : onTap,
      onHorizontalDragEnd: (details) {
        if (isSwitching) return;
        if (details.primaryVelocity == null) return;

        if (details.primaryVelocity! < -250) {
          // Swipe left -> Next
          onSkipNext?.call();
        } else if (details.primaryVelocity! > 250) {
          // Swipe right -> Previous
          onSkipPrevious?.call();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSwitching)
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child:
                isSwitching
                    ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                    : Row(
                      children: [
                        const SizedBox(width: 12),
                        Hero(
                          tag: 'player_art',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child:
                                  currentSong.artUri != null
                                      ? AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: CachedNetworkImage(
                                          key: ValueKey(
                                            currentSong.artUri!.toString(),
                                          ),
                                          imageUrl:
                                              currentSong.artUri!.toString(),
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (_, _) => Container(
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                              ),
                                          errorWidget:
                                              (_, _, _) => Icon(
                                                Icons.music_note,
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                        ),
                                      )
                                      : Icon(
                                        Icons.music_note,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentSong.title,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (isVideo) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiaryContainer
                                            .withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.mv,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                currentSong.artist ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            transitionBuilder:
                                (child, anim) => ScaleTransition(
                                  scale: anim,
                                  child: FadeTransition(
                                    opacity: anim,
                                    child: child,
                                  ),
                                ),
                            child: Icon(
                              playerState.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              key: ValueKey(playerState.isPlaying),
                            ),
                          ),
                          onPressed: onPlayPause,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: onSkipNext,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
