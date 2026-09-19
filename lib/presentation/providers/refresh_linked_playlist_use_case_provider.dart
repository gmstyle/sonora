import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/playlist/refresh_linked_playlist_use_case.dart';
import 'import_playlist_providers.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';

final refreshLinkedPlaylistUseCaseProvider =
    Provider<RefreshLinkedPlaylistUseCase>((ref) {
      final datasource = ref.watch(spotifyPlaylistDatasourceProvider);
      return RefreshLinkedPlaylistUseCase(
        ref.watch(musicRepositoryProvider),
        ref.watch(libraryRepositoryProvider),
        fetchSpotify: datasource.fetchPlaylist,
      );
    });
