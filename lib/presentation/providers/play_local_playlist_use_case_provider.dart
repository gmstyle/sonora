import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/player/play_local_playlist_use_case.dart';
import 'library_repository_provider.dart';
import 'play_video_id_use_case_provider.dart';

final playLocalPlaylistUseCaseProvider = Provider<PlayLocalPlaylistUseCase>((
  ref,
) {
  return PlayLocalPlaylistUseCase(
    ref.watch(playVideoIdUseCaseProvider),
    ref.watch(libraryRepositoryProvider),
  );
});
