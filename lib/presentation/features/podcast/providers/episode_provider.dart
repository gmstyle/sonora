import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/music_repository_provider.dart';

final episodeProvider = FutureProvider.family<EpisodeFull, String>((
  ref,
  videoId,
) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getEpisode(videoId);
});
