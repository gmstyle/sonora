import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/play_video_id_use_case.dart';
import 'music_repository_provider.dart';

final playVideoIdUseCaseProvider = Provider<PlayVideoIdUseCase>((ref) {
  return PlayVideoIdUseCase(ref.watch(musicRepositoryProvider));
});
