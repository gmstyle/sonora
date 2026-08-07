/// Streaming / download quality preference shared across playback and downloads.
enum MediaQuality {
  high,
  mid,
  low;

  String get storageValue => name;

  static MediaQuality fromStorage(String? value) {
    return switch (value) {
      'low' => MediaQuality.low,
      'mid' => MediaQuality.mid,
      'high' => MediaQuality.high,
      _ => MediaQuality.high,
    };
  }
}
