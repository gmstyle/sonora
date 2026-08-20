import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/player/play_podcast_use_case.dart';
import 'music_repository_provider.dart';

final playPodcastUseCaseProvider = Provider<PlayPodcastUseCase>((ref) {
  return PlayPodcastUseCase(ref.watch(musicRepositoryProvider));
});
