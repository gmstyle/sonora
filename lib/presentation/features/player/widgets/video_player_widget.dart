import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../providers/video_player_provider.dart';

class SonoraVideoPlayer extends ConsumerWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String tag;

  const SonoraVideoPlayer({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.tag = 'default',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child:
            videoState.isInitialized
                ? Video(
                  key: ValueKey('video_$tag'),
                  controller: videoState.controller,
                  fit: fit,
                  controls: NoVideoControls,
                )
                : Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
      ),
    );
  }
}
