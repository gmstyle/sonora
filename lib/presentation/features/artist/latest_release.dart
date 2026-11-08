import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

/// Studio album with the highest [AlbumDetailed.year] on an artist page.
///
/// Releases without a year are ignored. Returns null when none have a year.
AlbumDetailed? latestReleaseAlbum(List<AlbumDetailed> albums) {
  AlbumDetailed? best;
  for (final album in albums) {
    final year = album.year;
    if (year == null) continue;
    if (best == null || year > best.year!) best = album;
  }
  return best;
}
