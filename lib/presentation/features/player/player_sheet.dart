import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'mini_player_content.dart';
import 'full_player_content.dart';

class PlayerSheet extends ConsumerStatefulWidget {
  const PlayerSheet({super.key});

  @override
  ConsumerState<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends ConsumerState<PlayerSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final isVideo = currentSong.extras?['isVideo'] == true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        if (availableHeight <= 0) return const SizedBox.shrink();

        final minRatio = 72.0 / availableHeight;

        return DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: minRatio,
          minChildSize: minRatio,
          maxChildSize: 1.0,
          snap: true,
          snapSizes: [minRatio, 1.0],
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  MiniPlayerContent(
                    currentSong: currentSong,
                    playerState: playerState,
                    isVideo: isVideo,
                    onTap:
                        () => _controller.animateTo(
                          1.0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                    onPlayPause:
                        () =>
                            ref
                                .read(playerStateProvider.notifier)
                                .togglePlayPause(),
                    onSkipNext:
                        () =>
                            ref.read(playerStateProvider.notifier).skipToNext(),
                  ),
                  SizedBox(
                    height: availableHeight - 72,
                    child: const FullPlayerContent(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
