import 'dart:math';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/usecases/home/get_discover_suggestions_use_case.dart';
import 'package:sonora/domain/usecases/home/get_new_releases_use_case.dart';
import 'package:sonora/domain/usecases/home/get_similar_artists_suggestions_use_case.dart';
import 'package:sonora/presentation/providers/library_repository_provider.dart';
import 'package:sonora/presentation/providers/music_repository_provider.dart';

const _kHomeSectionMaxItems = 12;

final homeSectionsProvider = FutureProvider((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getHomeSections();
});

final recentHistoryProvider = FutureProvider((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getRecentHistory(limit: 10);
});

final homeCombinedPlaylistsProvider = FutureProvider<List<dynamic>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAllPlaylists().then((local) async {
    final liked = await repo.getAllLikedPlaylists();
    return [...local, ...liked];
  });
});

final homeRandomPlaylistsProvider = FutureProvider<List<dynamic>>((ref) async {
  final all = await ref.watch(homeCombinedPlaylistsProvider.future);
  final shuffled = List<dynamic>.from(all)..shuffle(Random());
  return shuffled.take(_kHomeSectionMaxItems).toList();
});

final homeRandomArtistsProvider = FutureProvider<List<FollowedArtistModel>>((
  ref,
) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final all = await repo.getAllFollowedArtists();
  final shuffled = List<FollowedArtistModel>.from(all)..shuffle(Random());
  return shuffled.take(_kHomeSectionMaxItems).toList();
});

final homeRandomAlbumsProvider = FutureProvider<List<LikedAlbumModel>>((
  ref,
) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final all = await repo.getAllLikedAlbums();
  final shuffled = List<LikedAlbumModel>.from(all)..shuffle(Random());
  return shuffled.take(_kHomeSectionMaxItems).toList();
});

final getNewReleasesUseCaseProvider = Provider<GetNewReleasesUseCase>((ref) {
  return GetNewReleasesUseCase(
    ref.watch(musicRepositoryProvider),
    ref.watch(libraryRepositoryProvider),
  );
});

final homeNewReleasesProvider = FutureProvider<List<AlbumDetailed>>((ref) {
  final useCase = ref.watch(getNewReleasesUseCaseProvider);
  return useCase.execute();
});

final homeRandomNewReleasesProvider = FutureProvider<List<AlbumDetailed>>((
  ref,
) async {
  final all = await ref.watch(homeNewReleasesProvider.future);
  final shuffled = List<AlbumDetailed>.from(all)..shuffle(Random());
  return shuffled.take(_kHomeSectionMaxItems).toList();
});

final getDiscoverSuggestionsUseCaseProvider =
    Provider<GetDiscoverSuggestionsUseCase>((ref) {
      return GetDiscoverSuggestionsUseCase(
        ref.watch(musicRepositoryProvider),
        ref.watch(libraryRepositoryProvider),
      );
    });

final homeDiscoverProvider = FutureProvider<List<UpNextsDetails>>((ref) {
  final useCase = ref.watch(getDiscoverSuggestionsUseCaseProvider);
  return useCase.execute();
});

final getSimilarArtistsSuggestionsUseCaseProvider =
    Provider<GetSimilarArtistsSuggestionsUseCase>((ref) {
      return GetSimilarArtistsSuggestionsUseCase(
        ref.watch(musicRepositoryProvider),
        ref.watch(libraryRepositoryProvider),
      );
    });

final homeSimilarArtistsProvider = FutureProvider<List<ArtistDetailed>>((ref) {
  final useCase = ref.watch(getSimilarArtistsSuggestionsUseCaseProvider);
  return useCase.execute();
});
