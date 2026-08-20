import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../models/queue_track.dart';
import '../../repositories/music_repository.dart';

/// Builds a [List<MediaItem>] from podcast episodes with episode metadata.
class PlayPodcastUseCase {
  final MusicRepository _repo;

  PlayPodcastUseCase(this._repo);

  Future<List<MediaItem>> execute(
    List<PodcastEpisode> episodes, {
    required String podcastBrowseId,
    String? podcastName,
    String? authorName,
    String? authorId,
    int playIndex = 0,
  }) async {
    final playable = episodes
        .where((e) => e.videoId.isNotEmpty)
        .toList(growable: false);
    if (playable.isEmpty) return [];

    final resolvedIndex =
        playIndex >= 0 && playIndex < playable.length ? playIndex : 0;

    String? firstUrl;
    if (playIndex >= 0) {
      try {
        firstUrl = await _repo.getStreamUrl(playable[resolvedIndex].videoId);
      } catch (_) {}
    }

    return [
      for (int i = 0; i < playable.length; i++)
        i == resolvedIndex && firstUrl != null
            ? _toMediaItem(
              playable[i],
              firstUrl,
              podcastBrowseId: podcastBrowseId,
              podcastName: podcastName,
              authorName: authorName,
              authorId: authorId,
            )
            : _toPendingMediaItem(
              playable[i],
              podcastBrowseId: podcastBrowseId,
              podcastName: podcastName,
              authorName: authorName,
              authorId: authorId,
            ),
    ];
  }

  MediaItem _toMediaItem(
    PodcastEpisode e,
    String url, {
    required String podcastBrowseId,
    String? podcastName,
    String? authorName,
    String? authorId,
  }) {
    final seconds = Parser.parseDuration(e.duration);
    final track = QueueTrack(
      videoId: e.videoId,
      url: url,
      isVideo: false,
      contentType: 'episode',
      podcastBrowseId: podcastBrowseId,
      artistId: authorId,
      title: e.name,
      artist: authorName ?? podcastName,
      album: podcastName,
      duration: seconds != null ? Duration(seconds: seconds) : null,
      artUri: e.thumbnails.isNotEmpty ? Uri.parse(e.thumbnails.last.url) : null,
      publishDate: e.date,
    );
    return track.toFreshMediaItem();
  }

  MediaItem _toPendingMediaItem(
    PodcastEpisode e, {
    required String podcastBrowseId,
    String? podcastName,
    String? authorName,
    String? authorId,
  }) {
    final seconds = Parser.parseDuration(e.duration);
    final track = QueueTrack(
      videoId: e.videoId,
      needsUrl: true,
      isVideo: false,
      contentType: 'episode',
      podcastBrowseId: podcastBrowseId,
      artistId: authorId,
      title: e.name,
      artist: authorName ?? podcastName,
      album: podcastName,
      duration: seconds != null ? Duration(seconds: seconds) : null,
      artUri: e.thumbnails.isNotEmpty ? Uri.parse(e.thumbnails.last.url) : null,
      publishDate: e.date,
    );
    return track.toFreshMediaItem();
  }
}
