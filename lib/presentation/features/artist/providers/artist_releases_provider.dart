import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/music_repository_provider.dart';
import 'artist_provider.dart';

enum ArtistReleaseKind { albums, singles }

enum ArtistReleaseSort { year, title }

/// Newest year first. Releases without a year sink to the bottom.
/// Title sort is case-insensitive A–Z. Equal keys fall back to the title.
List<AlbumDetailed> sortArtistReleases(
  List<AlbumDetailed> releases,
  ArtistReleaseSort sort,
) {
  final sorted = List<AlbumDetailed>.of(releases);
  int byTitle(AlbumDetailed a, AlbumDetailed b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  switch (sort) {
    case ArtistReleaseSort.year:
      sorted.sort((a, b) {
        final byYear = (b.year ?? -1).compareTo(a.year ?? -1);
        if (byYear != 0) return byYear;
        return byTitle(a, b);
      });
    case ArtistReleaseSort.title:
      sorted.sort(byTitle);
  }
  return sorted;
}

typedef ArtistReleasesKey = ({String artistId, ArtistReleaseKind kind});

/// Full artist catalog from [MusicRepository], with the artist-page preview
/// appended for any release the catalog call omitted.
///
/// `getArtistAlbums` / `getArtistSingles` follow discography continuations and
/// return an empty list when YouTube Music does not expose a "more" browse
/// endpoint (the carousel already holds every release). A failed catalog call
/// still shows that preview.
final artistReleasesProvider = FutureProvider.family<
  List<AlbumDetailed>,
  ArtistReleasesKey
>((ref, key) async {
  final repo = ref.watch(musicRepositoryProvider);

  List<AlbumDetailed> catalog = const [];
  Object? catalogError;
  StackTrace? catalogStack;
  try {
    final fetched = switch (key.kind) {
      ArtistReleaseKind.albums => await repo.getArtistAlbums(key.artistId),
      ArtistReleaseKind.singles => await repo.getArtistSingles(key.artistId),
    };
    catalog =
        key.kind == ArtistReleaseKind.singles
            ? fetched
                .where((release) => release.albumId.startsWith('M'))
                .toList()
            : fetched;
  } catch (error, stackTrace) {
    catalogError = error;
    catalogStack = stackTrace;
  }

  List<AlbumDetailed> preview = const [];
  try {
    final artist = await ref.watch(artistProvider(key.artistId).future);
    preview = switch (key.kind) {
      ArtistReleaseKind.albums => artist.topAlbums,
      ArtistReleaseKind.singles => artist.topSingles,
    };
  } catch (_) {}

  final merged = mergeArtistReleases(catalog, preview);
  if (merged.isEmpty && catalogError != null) {
    Error.throwWithStackTrace(catalogError, catalogStack!);
  }
  return merged;
});

/// Keeps [catalog] order, then appends preview rows whose id is missing.
List<AlbumDetailed> mergeArtistReleases(
  List<AlbumDetailed> catalog,
  List<AlbumDetailed> preview,
) {
  final seen = <String>{};
  final merged = <AlbumDetailed>[];
  for (final release in [...catalog, ...preview]) {
    final id = release.albumId;
    if (id.isEmpty || !seen.add(id)) continue;
    merged.add(release);
  }
  return merged;
}
