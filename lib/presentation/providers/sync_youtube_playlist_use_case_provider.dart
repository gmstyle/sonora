import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/playlist/sync_youtube_playlist_use_case.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';

final syncYoutubePlaylistUseCaseProvider = Provider<SyncYoutubePlaylistUseCase>(
  (ref) {
    return SyncYoutubePlaylistUseCase(
      ref.watch(musicRepositoryProvider),
      ref.watch(libraryRepositoryProvider),
    );
  },
);
