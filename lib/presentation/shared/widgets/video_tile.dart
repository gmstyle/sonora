import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'song_tile.dart';

class VideoTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? artistId;
  final String? thumbnailUrl;
  final int? duration;
  final String? albumName;
  final bool isExplicit;

  const VideoTile({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.artistId,
    this.thumbnailUrl,
    this.duration,
    this.albumName,
    this.isExplicit = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SongTile(
      videoId: videoId,
      title: title,
      artist: artist,
      artistId: artistId,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      isVideo: true,
      albumName: albumName,
      isExplicit: isExplicit,
    );
  }
}
