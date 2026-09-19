import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/play_album_use_case.dart';
import 'play_video_id_use_case_provider.dart';

final playAlbumUseCaseProvider = Provider<PlayAlbumUseCase>((ref) {
  return PlayAlbumUseCase(ref.watch(playVideoIdUseCaseProvider));
});
