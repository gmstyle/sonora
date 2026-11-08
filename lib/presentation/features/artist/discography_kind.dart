/// Shelves the artist discography chip can show.
enum ArtistDiscographyKind { albums, singles, videos }

/// Kinds that have at least one item, in shelf order.
List<ArtistDiscographyKind> artistDiscographyKinds({
  required bool hasAlbums,
  required bool hasSingles,
  required bool hasVideos,
}) {
  return [
    if (hasAlbums) ArtistDiscographyKind.albums,
    if (hasSingles) ArtistDiscographyKind.singles,
    if (hasVideos) ArtistDiscographyKind.videos,
  ];
}

/// Keeps [selected] when that shelf exists. Otherwise the first shelf.
///
/// Returns null when the artist has no albums, singles, or videos.
ArtistDiscographyKind? resolveDiscographyKind(
  List<ArtistDiscographyKind> available,
  ArtistDiscographyKind? selected,
) {
  if (available.isEmpty) return null;
  if (selected != null && available.contains(selected)) return selected;
  return available.first;
}
