/// Disk-cache size cap for [MediaCacheService] lookahead / offline files.
enum MediaCacheSize {
  mb500(500 * 1024 * 1024),
  gb1(1024 * 1024 * 1024),
  gb2(2 * 1024 * 1024 * 1024),
  gb5(5 * 1024 * 1024 * 1024);

  const MediaCacheSize(this.bytes);

  final int bytes;

  String get storageValue => name;

  /// Compact label for settings dropdowns (locale-invariant).
  String get displayLabel => switch (this) {
    MediaCacheSize.mb500 => '500 MB',
    MediaCacheSize.gb1 => '1 GB',
    MediaCacheSize.gb2 => '2 GB',
    MediaCacheSize.gb5 => '5 GB',
  };

  static MediaCacheSize fromStorage(String? value) {
    return switch (value) {
      'mb500' => MediaCacheSize.mb500,
      'gb1' => MediaCacheSize.gb1,
      'gb2' => MediaCacheSize.gb2,
      'gb5' => MediaCacheSize.gb5,
      _ => MediaCacheSize.gb1,
    };
  }
}
