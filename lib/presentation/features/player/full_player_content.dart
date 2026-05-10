import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../../providers/player_provider.dart';

class FullPlayerContent extends StatelessWidget {
  final MediaItem currentSong;
  final PlayerState playerState;
  final bool isVideo;

  const FullPlayerContent({
    super.key,
    required this.currentSong,
    required this.playerState,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Text(
          'Full Player — Fase 6',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
