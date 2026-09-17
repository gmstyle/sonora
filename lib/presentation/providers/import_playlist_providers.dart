import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/spotify_playlist_datasource.dart';
import '../../domain/usecases/playlist/import_remote_playlist_use_case.dart';
import '../../domain/usecases/playlist/import_spotify_playlist_use_case.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';
import 'sync_youtube_playlist_use_case_provider.dart';

final spotifyPlaylistDatasourceProvider = Provider<SpotifyPlaylistDatasource>(
  (ref) => SpotifyPlaylistDatasource(),
);

final importSpotifyPlaylistUseCaseProvider =
    Provider<ImportSpotifyPlaylistUseCase>((ref) {
      final datasource = ref.watch(spotifyPlaylistDatasourceProvider);
      return ImportSpotifyPlaylistUseCase(
        datasource.fetchPlaylist,
        ref.watch(musicRepositoryProvider),
        ref.watch(libraryRepositoryProvider),
      );
    });

final importRemotePlaylistUseCaseProvider =
    Provider<ImportRemotePlaylistUseCase>((ref) {
      return ImportRemotePlaylistUseCase(
        ref.watch(syncYoutubePlaylistUseCaseProvider),
        ref.watch(importSpotifyPlaylistUseCaseProvider),
      );
    });
