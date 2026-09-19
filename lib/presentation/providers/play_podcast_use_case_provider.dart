import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/player/play_podcast_use_case.dart';
import 'play_video_id_use_case_provider.dart';

final playPodcastUseCaseProvider = Provider<PlayPodcastUseCase>((ref) {
  return PlayPodcastUseCase(ref.watch(playVideoIdUseCaseProvider));
});
