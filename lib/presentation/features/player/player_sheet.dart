import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'mini_player_content.dart';
import 'full_player_content.dart';

class PlayerSheet extends ConsumerWidget {
  final double bottom;
  const PlayerSheet({super.key, this.bottom = 0.0});

  void _navigateToFullPlayer(
    BuildContext context,
    WidgetRef ref, {
    PlayerSubView subView = PlayerSubView.none,
  }) {
    if (subView != PlayerSubView.none) {
      ref.read(playerSubViewProvider.notifier).set(subView);
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                FullPlayerContent(initialSubView: subView),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final isVideo = currentSong.extras?['isVideo'] == true;

    return Positioned(
      bottom: bottom,
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
          onTap: () => _navigateToFullPlayer(context, ref),
          onPlayPause:
              () => ref.read(playerStateProvider.notifier).togglePlayPause(),
          onSkipNext: () => ref.read(playerStateProvider.notifier).skipToNext(),
          onSkipPrevious:
              () => ref.read(playerStateProvider.notifier).skipToPrevious(),
          onOpenLyrics:
              () => _navigateToFullPlayer(
                context,
                ref,
                subView: PlayerSubView.lyrics,
              ),
          onOpenQueue:
              () => _navigateToFullPlayer(
                context,
                ref,
                subView: PlayerSubView.queue,
              ),
        ),
      ),
    );
  }
}
