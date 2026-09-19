import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/play_playlist_use_case.dart';
import 'play_video_id_use_case_provider.dart';

final playPlaylistUseCaseProvider = Provider<PlayPlaylistUseCase>((ref) {
  return PlayPlaylistUseCase(ref.watch(playVideoIdUseCaseProvider));
});
