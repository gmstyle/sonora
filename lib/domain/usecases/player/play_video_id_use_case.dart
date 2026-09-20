import 'dart:io';
import '../../../data/services/media_cache_service.dart';

import 'package:audio_service/audio_service.dart';
import '../../../core/utils/connectivity_utils.dart';
import '../../models/queue_track.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';
import '../../../core/utils/artists_utils.dart';

/// Resolves a [videoId] to a fully populated [MediaItem] ready for playback.
///
/// Tries [MusicRepository.getSong] first; falls back to [MusicRepository.getVideo]
/// for music videos. If a local download exists, uses the local file instead of
/// resolving a stream URL.
class PlayVideoIdUseCase {
  final MusicRepository _repo;
  final LibraryRepository? _libraryRepo;
  final bool Function() _isForcedOffline;

  PlayVideoIdUseCase(
    this._repo, [
    this._libraryRepo,
    bool Function()? isForcedOffline,
  ]) : _isForcedOffline = isForcedOffline ?? _neverForcedOffline;

  static bool _neverForcedOffline() => false;

  /// Upper bound for a single stream-URL resolution.
  ///
  /// [StreamDatasource.getStreamUrl] retries up to 3 times on a YouTube 429
  /// (`RequestLimitExceededException`) with a 5s then 15s back-off between
  /// attempts (~20s of waiting alone, plus the network calls themselves).
  /// This timeout MUST stay comfortably above that worst case, otherwise the
  /// caller gives up (and the caller-side code treats it as a hard failure)
  /// before the datasource's own anti-429 back-off had a chance to succeed —
  /// which defeats the whole point of the back-off and can even cause a
  /// pile-up of abandoned-but-still-running requests that make the 429
  /// situation worse.
  static const Duration streamUrlTimeout = Duration(seconds: 40);

  Future<MediaItem> execute(
    String videoId, {
    bool? isVideoHint,
    bool? isExplicitHint,
  }) async {
    // Single playback URL entry point (download → media-cache → stream).
    final url = await resolveUrl(videoId).timeout(streamUrlTimeout);

    // Prefer library-download metadata when the resolved URI is that file.
    if (_libraryRepo != null &&
        url.startsWith('file://') &&
        !MediaCacheService.isMediaCacheUri(url)) {
      try {
        final download = await _libraryRepo.getDownload(videoId);
        if (download != null && download.status == 'completed') {
          return QueueTrack(
            videoId: videoId,
            url: url,
            isVideo: download.isVideo,
            isExplicit: download.isExplicit,
            title: download.title,
            artist: download.artist,
            artistsJson: download.artistsJson,
            artUri:
                download.thumbnailUrl != null &&
                        download.thumbnailUrl!.isNotEmpty
                    ? Uri.parse(download.thumbnailUrl!)
                    : null,
          ).toFreshMediaItem();
        }
      } catch (_) {}
    }

    // Cache-only / offline: playable URI without catalog metadata.
    final forcedOffline = _isForcedOffline();
    final physicalOffline = await ConnectivityUtils.isOffline();
    if (forcedOffline || physicalOffline) {
      return QueueTrack(
        videoId: videoId,
        url: url,
        isVideo: isVideoHint ?? false,
        isExplicit: isExplicitHint ?? false,
        title: videoId,
      ).toFreshMediaItem();
    }

    String title, artist, thumbnailUrl;
    int durationSec;
    bool isVideo;
    int? viewCount;
    String? publishDate;
    String? artistId;
    String? albumId;
    String? artistsJson;
    bool isExplicit = false;

    try {
      final song = await _repo
          .getSong(videoId)
          .timeout(const Duration(seconds: 10));
      title = song.name;
      artist = displayArtists(song.artists);
      durationSec = song.duration;
      thumbnailUrl = song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '';
      isVideo = isVideoHint ?? (song.type == 'VIDEO');
      viewCount = song.viewCount;
      publishDate = song.publishDate;
      artistId = primaryArtistId(song.artists);
      albumId = song.album?.albumId;
      artistsJson = encodeArtistsJson(song.artists);
      isExplicit = isExplicitHint ?? song.isExplicit;
    } catch (_) {
      final video = await _repo
          .getVideo(videoId)
          .timeout(const Duration(seconds: 10));
      title = video.name;
      artist = displayArtists(video.artists);
      durationSec = video.duration;
      thumbnailUrl =
          video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
      isVideo = true;
      viewCount = video.viewCount;
      publishDate = video.publishDate;
      artistId = primaryArtistId(video.artists);
      artistsJson = encodeArtistsJson(video.artists);
      isExplicit = isExplicitHint ?? video.isExplicit;
    }

    if (_libraryRepo != null && durationSec > 0) {
      _libraryRepo
          .updateSongMetadata(videoId, durationSec, isExplicit)
          .catchError((_) => null);
    }

    final track = QueueTrack(
      videoId: videoId,
      url: url,
      isVideo: isVideo,
      isExplicit: isExplicit,
      artistId: artistId,
      albumId: albumId,
      artistsJson: artistsJson,
      viewCount: viewCount,
      publishDate: publishDate,
      title: title,
      artist: artist,
      duration: Duration(seconds: durationSec),
      artUri: thumbnailUrl.isNotEmpty ? Uri.parse(thumbnailUrl) : null,
    );
    return track.toFreshMediaItem();
  }

  /// Single playback URL entry point for the app (except cast / download /
  /// proxy stream acquisition).
  ///
  /// Order: completed library download → audio-only media-cache hit →
  /// live stream via [resolveStreamUrl].
  Future<String> resolveUrl(String videoId) async {
    final local = await resolveCompletedDownloadUrl(videoId, _libraryRepo);
    if (local != null) {
      return local;
    }

    final forcedOffline = _isForcedOffline();
    if (forcedOffline) {
      throw const SocketException('Offline: cannot resolve stream URL.');
    }

    try {
      final hit = await MediaCacheService.instance.getCachedHit(videoId);
      if (hit != null) {
        return hit.primaryUri;
      }
    } catch (_) {}

    // Fail fast if offline
    final offline = await ConnectivityUtils.isOffline();
    if (offline) {
      throw const SocketException('Offline: cannot resolve stream URL.');
    }

    return await resolveStreamUrl(videoId);
  }

  /// Resolves the YouTube stream URL only (no download / cache). Used by cast
  /// and callers that already know they need a remote stream.
  Future<String> resolveStreamUrl(String videoId) async {
    return _repo.getStreamUrl(videoId).timeout(streamUrlTimeout);
  }
}

/// Returns a `file://` URI when [videoId] has a completed download still on
/// disk. Removes the library row if the file is gone.
Future<String?> resolveCompletedDownloadUrl(
  String videoId,
  LibraryRepository? libraryRepo,
) async {
  if (libraryRepo == null) return null;
  try {
    final download = await libraryRepo.getDownload(videoId);
    if (download != null &&
        download.status == 'completed' &&
        download.localPath != null) {
      final file = File(download.localPath!);
      if (await file.exists()) {
        return file.uri.toString();
      }
      await libraryRepo.deleteDownload(videoId);
    }
  } catch (_) {}
  return null;
}
