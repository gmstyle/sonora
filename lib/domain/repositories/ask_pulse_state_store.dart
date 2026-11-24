abstract class AskPulseStateStore {
  Future<Map<String, List<String>>> getSeenReleasesByArtist();

  Future<void> saveSeenReleasesByArtist(Map<String, List<String>> seen);

  Future<int> getArtistCursor();

  Future<void> setArtistCursor(int cursor);

  Future<Map<String, List<String>>> getSeenEpisodesByPodcast();

  Future<void> saveSeenEpisodesByPodcast(Map<String, List<String>> seen);

  Future<int> getPodcastCursor();

  Future<void> setPodcastCursor(int cursor);
}
