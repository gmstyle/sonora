import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';

final playlistProvider = FutureProvider.family<PlaylistFull, String>((
  ref,
  playlistId,
) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getPlaylist(playlistId, limit: 100);
});

final playlistVideosProvider =
    FutureProvider.family<List<VideoDetailed>, String>((ref, playlistId) async {
      final playlist = await ref.watch(playlistProvider(playlistId).future);
      if (playlist.tracks.isNotEmpty) return playlist.tracks;
      final repo = ref.watch(musicRepositoryProvider);
      return repo.getPlaylistVideos(playlistId);
    });
