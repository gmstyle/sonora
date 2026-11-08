import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/library_repository_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../../domain/models/library_models.dart';

enum LibrarySortType {
  alphabetical,
  alphabeticalReverse,
  recentlyAdded,
  leastRecentlyAdded,
}

const _kSortTypeKey = 'librarySortType';

class LibrarySortTypeNotifier extends Notifier<LibrarySortType> {
  @override
  LibrarySortType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final index =
        prefs.getInt(_kSortTypeKey) ?? LibrarySortType.recentlyAdded.index;
    if (index >= 0 && index < LibrarySortType.values.length) {
      return LibrarySortType.values[index];
    }
    return LibrarySortType.recentlyAdded;
  }

  void update(LibrarySortType value) {
    state = value;
    ref.read(sharedPreferencesProvider).setInt(_kSortTypeKey, value.index);
  }
}

final librarySortTypeProvider =
    NotifierProvider<LibrarySortTypeNotifier, LibrarySortType>(
      LibrarySortTypeNotifier.new,
    );

final likedSongsProvider = StreamProvider<List<LikedSongModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllLikedSongs();
});

final sortedLikedSongsProvider = Provider<AsyncValue<List<LikedSongModel>>>((
  ref,
) {
  final songsAsync = ref.watch(likedSongsProvider);
  final sortType = ref.watch(librarySortTypeProvider);

  return songsAsync.whenData((songs) {
    final list = List<LikedSongModel>.from(songs);

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
      final sortType = ref.watch(librarySortTypeProvider);

      return artistsAsync.whenData((artists) {
        final list = List<FollowedArtistModel>.from(artists);

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
  final sortType = ref.watch(librarySortTypeProvider);

  return playlistsAsync.whenData((playlists) {
    final list = List<LocalPlaylistModel>.from(playlists);

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
  final sortType = ref.watch(librarySortTypeProvider);

  return historyAsync.whenData((history) {
    final list = List<HistoryModel>.from(history);

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
  final sortType = ref.watch(librarySortTypeProvider);

  return albumsAsync.whenData((albums) {
    final list = List<LikedAlbumModel>.from(albums);

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
      final sortType = ref.watch(librarySortTypeProvider);

      return playlistsAsync.whenData((playlists) {
        final list = List<LikedPlaylistModel>.from(playlists);

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

final likedPodcastsProvider = StreamProvider<List<LikedPodcastModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchAllLikedPodcasts();
});

final sortedLikedPodcastsProvider =
    Provider<AsyncValue<List<LikedPodcastModel>>>((ref) {
      final podcastsAsync = ref.watch(likedPodcastsProvider);
      final sortType = ref.watch(librarySortTypeProvider);

      return podcastsAsync.whenData((podcasts) {
        final list = List<LikedPodcastModel>.from(podcasts);

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

enum LibraryTab {
  favorites,
  artists,
  playlists,
  albums,
  podcasts,
  history,
  mixes,
  stats;

  /// Always-visible Library chrome tabs.
  static const List<LibraryTab> primaryTabs = [
    favorites,
    artists,
    playlists,
    albums,
  ];

  /// Tabs reachable via the overflow ("More" / "Altro") menu.
  static const List<LibraryTab> overflowTabs = [
    podcasts,
    history,
    mixes,
    stats,
  ];

  bool get isPrimary => primaryTabs.contains(this);

  bool get isOverflow => overflowTabs.contains(this);

  /// Tabs that support list/grid view switching in [LibraryHeaderControls].
  bool get supportsListGridView => switch (this) {
    artists || playlists || albums || podcasts || mixes => true,
    _ => false,
  };

  bool get showsHeaderControls => this != stats;

  bool get showsClearHistory => this == history;
}

class LibraryActiveTabNotifier extends Notifier<LibraryTab> {
  @override
  LibraryTab build() => LibraryTab.favorites;
  void update(LibraryTab value) => state = value;
}

final libraryActiveTabProvider =
    NotifierProvider<LibraryActiveTabNotifier, LibraryTab>(
      LibraryActiveTabNotifier.new,
    );
