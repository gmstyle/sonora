import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/start_radio_use_case.dart';
import 'music_repository_provider.dart';
import 'play_video_id_use_case_provider.dart';

final startRadioUseCaseProvider = Provider<StartRadioUseCase>((ref) {
  return StartRadioUseCase(
    ref.watch(musicRepositoryProvider),
    ref.watch(playVideoIdUseCaseProvider),
  );
});
