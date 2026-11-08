/// Featured playlists kept beside popular songs on a wide artist page.
const int kFeaturedSidePreviewCount = 5;

/// The rows that stay in the side column.
List<T> featuredSidePreview<T>(List<T> playlists) {
  if (playlists.length <= kFeaturedSidePreviewCount) return playlists;
  return playlists.sublist(0, kFeaturedSidePreviewCount);
}

/// Playlists after the side-column preview.
List<T> featuredSideOverflow<T>(List<T> playlists) {
  if (playlists.length <= kFeaturedSidePreviewCount) return List<T>.empty();
  return playlists.sublist(kFeaturedSidePreviewCount);
}
