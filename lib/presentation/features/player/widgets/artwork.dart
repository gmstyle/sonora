import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/palette_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/video_player_provider.dart';
import 'player_shared_widgets.dart';
import 'video_player_widget.dart';

class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    required this.artUrl,
    required this.size,
    required this.videoId,
    this.isSwitching = false,
    this.isVideo = false,
  });

  final String? artUrl;
  final double size;
  final String videoId;
  final bool isSwitching;
  final bool isVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    if (isVideo && videoState.isVideoVisible && videoState.isInitialized) {
      return SonoraVideoPlayer(
        width: size,
        height: size / videoState.aspectRatio,
        borderRadius: BorderRadius.circular(12),
        tag: 'full',
      );
    }
    final paletteMap = ref.watch(paletteNotifierProvider);
    final paletteData = paletteMap[videoId];
    final dominantColor =
        paletteData?.dominantColor ??
        Theme.of(context).colorScheme.primaryContainer;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    return buildArtwork(
      context,
      artUrl,
      isSwitching,
      size,
      dominantColor,
      reduceEffects: reduceEffects,
    );
  }
}
