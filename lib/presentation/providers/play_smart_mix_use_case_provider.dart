import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/play_smart_mix_use_case.dart';
import 'play_video_id_use_case_provider.dart';

final playSmartMixUseCaseProvider = Provider<PlaySmartMixUseCase>((ref) {
  return PlaySmartMixUseCase(ref.watch(playVideoIdUseCaseProvider));
});
