import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/start_radio_use_case.dart';
import 'music_repository_provider.dart';

final startRadioUseCaseProvider = Provider<StartRadioUseCase>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return StartRadioUseCase(repo);
});
