import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/music_repository_provider.dart';

typedef UserContentParams = ({String channelId, String params});

final userProvider = FutureProvider.family<UserFull, String>((ref, channelId) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getUser(channelId);
});

final userVideosProvider =
    FutureProvider.family<List<VideoDetailed>, UserContentParams>((ref, key) {
      final repo = ref.watch(musicRepositoryProvider);
      return repo.getUserVideos(key.channelId, key.params);
    });

final userPlaylistsProvider =
    FutureProvider.family<List<PlaylistDetailed>, UserContentParams>((
      ref,
      key,
    ) {
      final repo = ref.watch(musicRepositoryProvider);
      return repo.getUserPlaylists(key.channelId, key.params);
    });
