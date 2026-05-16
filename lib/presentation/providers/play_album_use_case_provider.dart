import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/player/play_album_use_case.dart';
import 'music_repository_provider.dart';

final playAlbumUseCaseProvider = Provider<PlayAlbumUseCase>((ref) {
  return PlayAlbumUseCase(ref.watch(musicRepositoryProvider));
});
