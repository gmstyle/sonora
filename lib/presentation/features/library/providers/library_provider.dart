import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/library_repository_provider.dart';
import '../../../../domain/models/library_models.dart';

enum LibrarySortType {
  alphabetical,
  alphabeticalReverse,
  recentlyAdded,
  leastRecentlyAdded,
}

class LibrarySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) {
    state = value;
    if (value.trim().isEmpty) {
      ref
          .read(librarySearchFilterProvider.notifier)
          .update(LibrarySearchFilter.all);
    }
  }
}

final librarySearchQueryProvider =
    NotifierProvider<LibrarySearchQueryNotifier, String>(
      LibrarySearchQueryNotifier.new,
    );

class LibrarySortTypeNotifier extends Notifier<LibrarySortType> {
  @override
  LibrarySortType build() => LibrarySortType.recentlyAdded;
  void update(LibrarySortType value) => state = value;
}

final librarySortTypeProvider =
    NotifierProvider<LibrarySortTypeNotifier, LibrarySortType>(
      LibrarySortTypeNotifier.new,
    );

enum LibrarySearchFilter { all, songs, artists, playlists, albums, history }

class LibrarySearchFilterNotifier extends Notifier<LibrarySearchFilter> {
  @override
  LibrarySearchFilter build() => LibrarySearchFilter.all;
  void update(LibrarySearchFilter value) => state = value;
}

final librarySearchFilterProvider =
    NotifierProvider<LibrarySearchFilterNotifier, LibrarySearchFilter>(
      LibrarySearchFilterNotifier.new,
    );

final likedSongsProvider = StreamProvider<List<LikedSongModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllLikedSongs();
});

final sortedLikedSongsProvider = Provider<AsyncValue<List<LikedSongModel>>>((
  ref,
) {
  final songsAsync = ref.watch(likedSongsProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final sortType = ref.watch(librarySortTypeProvider);

  return songsAsync.whenData((songs) {
    var list = List<LikedSongModel>.from(songs);
    if (query.isNotEmpty) {
      list =
          list
              .where(
                (s) =>
                    s.title.toLowerCase().contains(query) ||
                    s.artist.toLowerCase().contains(query),
              )
              .toList();
    }

    switch (sortType) {
      case LibrarySortType.alphabetical:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case LibrarySortType.alphabeticalReverse:
        list.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case LibrarySortType.recentlyAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySortType.leastRecentlyAdded:
        list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    }
    return list;
  });
});

final followedArtistsProvider = StreamProvider<List<FollowedArtistModel>>((
  ref,
) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllFollowedArtists();
});

final sortedFollowedArtistsProvider =
    Provider<AsyncValue<List<FollowedArtistModel>>>((ref) {
      final artistsAsync = ref.watch(followedArtistsProvider);
      final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
      final sortType = ref.watch(librarySortTypeProvider);

      return artistsAsync.whenData((artists) {
        var list = List<FollowedArtistModel>.from(artists);
        if (query.isNotEmpty) {
          list =
              list.where((a) => a.name.toLowerCase().contains(query)).toList();
        }

        switch (sortType) {
          case LibrarySortType.alphabetical:
            list.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          case LibrarySortType.alphabeticalReverse:
            list.sort(
              (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
            );
          case LibrarySortType.recentlyAdded:
            list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          case LibrarySortType.leastRecentlyAdded:
            list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        }
        return list;
      });
    });

final playlistsProvider = StreamProvider<List<LocalPlaylistModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllPlaylists();
});

final sortedPlaylistsProvider = Provider<AsyncValue<List<LocalPlaylistModel>>>((
  ref,
) {
  final playlistsAsync = ref.watch(playlistsProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final sortType = ref.watch(librarySortTypeProvider);

  return playlistsAsync.whenData((playlists) {
    var list = List<LocalPlaylistModel>.from(playlists);
    if (query.isNotEmpty) {
      list =
          list
              .where(
                (p) =>
                    p.name.toLowerCase().contains(query) ||
                    (p.description != null &&
                        p.description!.toLowerCase().contains(query)),
              )
              .toList();
    }

    switch (sortType) {
      case LibrarySortType.alphabetical:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case LibrarySortType.alphabeticalReverse:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case LibrarySortType.recentlyAdded:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case LibrarySortType.leastRecentlyAdded:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return list;
  });
});

final playlistEntriesProvider =
    StreamProvider.family<List<PlaylistEntryModel>, int>((ref, playlistId) {
      final repo = ref.watch(libraryRepositoryProvider);
      return repo.watchPlaylistEntries(playlistId);
    });

final libraryHistoryProvider = StreamProvider<List<HistoryModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchRecentHistory(limit: 50);
});

final sortedHistoryProvider = Provider<AsyncValue<List<HistoryModel>>>((ref) {
  final historyAsync = ref.watch(libraryHistoryProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final sortType = ref.watch(librarySortTypeProvider);

  return historyAsync.whenData((history) {
    var list = List<HistoryModel>.from(history);
    if (query.isNotEmpty) {
      list =
          list
              .where(
                (h) =>
                    h.title.toLowerCase().contains(query) ||
                    h.artist.toLowerCase().contains(query),
              )
              .toList();
    }

    switch (sortType) {
      case LibrarySortType.alphabetical:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case LibrarySortType.alphabeticalReverse:
        list.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case LibrarySortType.recentlyAdded:
        list.sort((a, b) => b.playedAt.compareTo(a.playedAt));
      case LibrarySortType.leastRecentlyAdded:
        list.sort((a, b) => a.playedAt.compareTo(b.playedAt));
    }
    return list;
  });
});

final likedAlbumsProvider = StreamProvider<List<LikedAlbumModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllLikedAlbums();
});

final sortedLikedAlbumsProvider = Provider<AsyncValue<List<LikedAlbumModel>>>((
  ref,
) {
  final albumsAsync = ref.watch(likedAlbumsProvider);
  final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
  final sortType = ref.watch(librarySortTypeProvider);

  return albumsAsync.whenData((albums) {
    var list = List<LikedAlbumModel>.from(albums);
    if (query.isNotEmpty) {
      list =
          list
              .where(
                (a) =>
                    a.name.toLowerCase().contains(query) ||
                    a.artistName.toLowerCase().contains(query),
              )
              .toList();
    }

    switch (sortType) {
      case LibrarySortType.alphabetical:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case LibrarySortType.alphabeticalReverse:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case LibrarySortType.recentlyAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySortType.leastRecentlyAdded:
        list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
    }
    return list;
  });
});

final likedPlaylistsProvider = StreamProvider<List<LikedPlaylistModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllLikedPlaylists();
});

final sortedLikedPlaylistsProvider =
    Provider<AsyncValue<List<LikedPlaylistModel>>>((ref) {
      final playlistsAsync = ref.watch(likedPlaylistsProvider);
      final query = ref.watch(librarySearchQueryProvider).trim().toLowerCase();
      final sortType = ref.watch(librarySortTypeProvider);

      return playlistsAsync.whenData((playlists) {
        var list = List<LikedPlaylistModel>.from(playlists);
        if (query.isNotEmpty) {
          list =
              list.where((p) => p.name.toLowerCase().contains(query)).toList();
        }

        switch (sortType) {
          case LibrarySortType.alphabetical:
            list.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          case LibrarySortType.alphabeticalReverse:
            list.sort(
              (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
            );
          case LibrarySortType.recentlyAdded:
            list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          case LibrarySortType.leastRecentlyAdded:
            list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        }
        return list;
      });
    });

class LibraryActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final libraryActiveTabProvider =
    NotifierProvider<LibraryActiveTabNotifier, int>(
      LibraryActiveTabNotifier.new,
    );
