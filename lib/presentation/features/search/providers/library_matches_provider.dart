import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/providers/library_provider.dart';
import '../library_matches.dart';

/// Library rows matching [query]. Empty when [query] is blank.
/// Streams that are still loading contribute an empty list until they emit.
final libraryMatchesProvider = Provider.family<LibraryMatches, String>((
  ref,
  query,
) {
  List<T> ready<T>(AsyncValue<List<T>> value) => value.asData?.value ?? [];

  return filterLibraryCollections(
    query: query,
    songs: ready(ref.watch(likedSongsProvider)),
    artists: ready(ref.watch(followedArtistsProvider)),
    playlists: ready(ref.watch(playlistsProvider)),
    likedPlaylists: ready(ref.watch(likedPlaylistsProvider)),
    albums: ready(ref.watch(likedAlbumsProvider)),
    podcasts: ready(ref.watch(likedPodcastsProvider)),
    history: ready(ref.watch(libraryHistoryProvider)),
  );
});
