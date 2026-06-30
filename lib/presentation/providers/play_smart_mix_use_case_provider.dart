import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/play_smart_mix_use_case.dart';
import 'music_repository_provider.dart';

final playSmartMixUseCaseProvider = Provider<PlaySmartMixUseCase>((ref) {
  return PlaySmartMixUseCase(ref.watch(musicRepositoryProvider));
});
