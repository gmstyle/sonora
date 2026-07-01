import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';

class RadioResult {
  final MediaItem firstItem;
  final List<UpNextsDetails> remaining;

  const RadioResult(this.firstItem, this.remaining);
}

class StartRadioUseCase {
  final MusicRepository _musicRepository;

  StartRadioUseCase(this._musicRepository);

  Future<RadioResult> execute(
    String seedVideoId, {
    bool resolveFirstUrl = true,
  }) async {
    final upNexts = await _musicRepository.getUpNexts(seedVideoId);
    if (upNexts.isEmpty) throw StateError('No radio items available');

    final first = upNexts.first;
    final MediaItem firstItem;
    if (resolveFirstUrl) {
      final firstUrl = await _musicRepository.getStreamUrl(first.videoId);
      firstItem = _mapToMediaItem(first, firstUrl);
    } else {
      firstItem = _toPendingMediaItem(first);
    }

    return RadioResult(firstItem, upNexts.sublist(1));
  }

  /// Creates [MediaItem]s for [items] without resolving stream URLs.
  /// Items are tagged with [needsUrl] so the player can resolve them
  /// lazily when they are about to play.
  List<MediaItem> toPendingItems(List<UpNextsDetails> items) {
    return items.map(_toPendingMediaItem).toList();
  }

  MediaItem _toPendingMediaItem(UpNextsDetails item) {
    return MediaItem(
      id: item.videoId,
      title: item.title,
      artist: item.artists.name,
      album: item.album?.name,
      duration: Duration(seconds: item.duration),
      artUri:
          item.thumbnails.isNotEmpty
              ? Uri.parse(item.thumbnails.last.url)
              : null,
      extras: {
        'needsUrl': true,
        'videoId': item.videoId,
        'isVideo': item.type == 'VIDEO',
        'artistId': item.artists.artistId,
        if (item.album?.albumId != null) 'albumId': item.album!.albumId,
        'isExplicit': item.isExplicit,
      },
    );
  }

  MediaItem _mapToMediaItem(UpNextsDetails item, String url) {
    return MediaItem(
      id: item.videoId,
      title: item.title,
      artist: item.artists.name,
      album: item.album?.name,
      duration: Duration(seconds: item.duration),
      artUri:
          item.thumbnails.isNotEmpty
              ? Uri.parse(item.thumbnails.last.url)
              : null,
      extras: {
        'url': url,
        'videoId': item.videoId,
        'isVideo': item.type == 'VIDEO',
        'artistId': item.artists.artistId,
        if (item.album?.albumId != null) 'albumId': item.album!.albumId,
        'isExplicit': item.isExplicit,
      },
    );
  }
}
