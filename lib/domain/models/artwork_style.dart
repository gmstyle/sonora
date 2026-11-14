/// How the player draws the current cover.
///
/// Episodes ignore this and stay on [plain]: show art is a square cover.
enum ArtworkStyle {
  /// Rotating record with a fixed tonearm.
  vinyl,

  /// Cover with an accent arc orbiting the rim.
  pulse,

  /// Cover with the logomark bars along the bottom edge.
  bars,

  /// The square cover, with no stage around it.
  plain;

  static ArtworkStyle fromStorage(String? raw) {
    return switch (raw) {
      'pulse' => ArtworkStyle.pulse,
      'bars' => ArtworkStyle.bars,
      'plain' => ArtworkStyle.plain,
      _ => ArtworkStyle.vinyl,
    };
  }

  /// `useVinylStyle` from older installs and backups.
  ///
  /// `false` is the plain cover. Missing or `true` is the vinyl stage,
  /// which was the previous default.
  static ArtworkStyle fromLegacyBool(bool? vinyl) {
    return vinyl == false ? ArtworkStyle.plain : ArtworkStyle.vinyl;
  }

  String get storageValue => name;

  /// Episodes keep the plain cover. Songs and videos use [this].
  ArtworkStyle forPlayback({required bool isEpisode}) {
    return isEpisode ? ArtworkStyle.plain : this;
  }
}
