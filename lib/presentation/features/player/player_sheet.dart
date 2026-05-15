import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'mini_player_content.dart';
import 'full_player_content.dart';

class PlayerSheet extends ConsumerWidget {
  const PlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final isVideo = currentSong.extras?['isVideo'] == true;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: MiniPlayerContent(
          currentSong: currentSong,
          playerState: playerState,
          isVideo: isVideo,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const FullPlayerContent(),
              ),
            );
          },
          onPlayPause:
              () => ref.read(playerStateProvider.notifier).togglePlayPause(),
          onSkipNext:
              () => ref.read(playerStateProvider.notifier).skipToNext(),
        ),
      ),
    );
  }
}
