import 'dart:io';

import 'package:audio_service/audio_service.dart';
import '../../repositories/library_repository.dart';
import '../../repositories/music_repository.dart';

/// Resolves a [videoId] to a fully populated [MediaItem] ready for playback.
///
/// Tries [MusicRepository.getSong] first; falls back to [MusicRepository.getVideo]
/// for music videos. If a local download exists, uses the local file instead of
/// resolving a stream URL.
class PlayVideoIdUseCase {
  final MusicRepository _repo;
  final LibraryRepository? _libraryRepo;

  PlayVideoIdUseCase(this._repo, [this._libraryRepo]);

  Future<MediaItem> execute(String videoId) async {
    // Pre-warm: start stream URL resolution in parallel with metadata fetch
    final urlFuture = resolveUrl(videoId);

    String title, artist, thumbnailUrl;
    int durationSec;
    bool isVideo;
    int? viewCount;
    String? publishDate;
    String? musicVideoType;
    String? artistId;
    String? albumId;

    try {
      final song = await _repo.getSong(videoId);
      title = song.name;
      artist = song.artist.name;
      durationSec = song.duration;
      thumbnailUrl = song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '';
      isVideo = false;
      viewCount = song.viewCount;
      publishDate = song.publishDate;
      artistId = song.artist.artistId;
      albumId = song.album?.albumId;
    } catch (_) {
      final video = await _repo.getVideo(videoId);
      title = video.name;
      artist = video.artist.name;
      durationSec = video.duration;
      thumbnailUrl =
          video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
      isVideo = true;
      viewCount = video.viewCount;
      publishDate = video.publishDate;
      musicVideoType = video.musicVideoType;
      artistId = video.artist.artistId;
    }

    final url = await urlFuture;
    final extras = <String, dynamic>{
      'url': url,
      'videoId': videoId,
      'isVideo': isVideo,
    };
    if (viewCount != null) extras['viewCount'] = viewCount;
    if (publishDate != null) extras['publishDate'] = publishDate;
    if (musicVideoType != null) extras['musicVideoType'] = musicVideoType;
    if (artistId != null) extras['artistId'] = artistId;
    if (albumId != null) extras['albumId'] = albumId;

    return MediaItem(
      id: videoId,
      title: title,
      artist: artist,
      duration: Duration(seconds: durationSec),
      artUri: thumbnailUrl.isNotEmpty ? Uri.parse(thumbnailUrl) : null,
      extras: extras,
    );
  }

  /// Returns a local file URI if a completed download exists and the file
  /// is still on disk (cleans up stale downloads), otherwise resolves the
  /// stream URL from [MusicRepository].
  Future<String> resolveUrl(String videoId) async {
    if (_libraryRepo != null) {
      try {
        final download = await _libraryRepo.getDownload(videoId);
        if (download != null &&
            download.status == 'completed' &&
            download.localPath != null) {
          final file = File(download.localPath!);
          if (await file.exists()) {
            return file.uri.toString();
          }
          await _libraryRepo.deleteDownload(videoId);
        }
      } catch (_) {}
    }
    return await resolveStreamUrl(videoId);
  }

  /// Resolves only the audio stream URL for [videoId].
  /// Used when metadata (title, artist, etc.) is already available from the UI.
  Future<String> resolveStreamUrl(String videoId) async {
    return _repo.getStreamUrl(videoId);
  }
}
