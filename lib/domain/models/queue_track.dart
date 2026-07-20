import 'package:audio_service/audio_service.dart';

/// Typed domain model for a playback track's metadata.
///
/// Replaces the stringly-typed `MediaItem.extras` map with explicit fields,
/// giving compile-time safety for every access. Mapping to/from [MediaItem]
/// happens only at the boundaries where `audio_service` requires it.
///
/// Queue-management fields (`section`, `queueId`) are NOT part of this model
/// because they are orthogonal to track metadata and are managed exclusively
/// by [QueueController].
class QueueTrack {
  final String videoId;
  final String? url;
  final bool needsUrl;
  final bool isVideo;
  final bool isExplicit;
  final String? artistId;
  final String? albumId;
  final int? viewCount;
  final String? publishDate;

  // Display fields (populated from DB on restore, from extras on live items).
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final Uri? artUri;

  const QueueTrack({
    required this.videoId,
    this.url,
    this.needsUrl = false,
    this.isVideo = false,
    this.isExplicit = false,
    this.artistId,
    this.albumId,
    this.viewCount,
    this.publishDate,
    this.title = '',
    this.artist,
    this.album,
    this.duration,
    this.artUri,
  });

  QueueTrack copyWith({
    String? videoId,
    String? url,
    bool? needsUrl,
    bool? isVideo,
    bool? isExplicit,
    String? artistId,
    String? albumId,
    int? viewCount,
    String? publishDate,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
    bool clearUrl = false,
    bool clearArtistId = false,
    bool clearAlbumId = false,
    bool clearViewCount = false,
    bool clearPublishDate = false,
    bool clearArtist = false,
    bool clearAlbumField = false,
    bool clearDuration = false,
    bool clearArtUri = false,
  }) {
    return QueueTrack(
      videoId: videoId ?? this.videoId,
      url: clearUrl ? null : (url ?? this.url),
      needsUrl: needsUrl ?? this.needsUrl,
      isVideo: isVideo ?? this.isVideo,
      isExplicit: isExplicit ?? this.isExplicit,
      artistId: clearArtistId ? null : (artistId ?? this.artistId),
      albumId: clearAlbumId ? null : (albumId ?? this.albumId),
      viewCount: clearViewCount ? null : (viewCount ?? this.viewCount),
      publishDate: clearPublishDate ? null : (publishDate ?? this.publishDate),
      title: title ?? this.title,
      artist: clearArtist ? null : (artist ?? this.artist),
      album: clearAlbumField ? null : (album ?? this.album),
      duration: clearDuration ? null : (duration ?? this.duration),
      artUri: clearArtUri ? null : (artUri ?? this.artUri),
    );
  }

  /// Whether this track has a resolved, usable URL.
  bool get hasUrl => url != null && url!.isNotEmpty && !needsUrl;

  /// Whether the URL looks like a local file (downloaded track).
  bool get isLocalFile => url != null && url!.startsWith('file://');

  // ── Boundary mapping: QueueTrack ↔ MediaItem ─────────────────────

  /// Creates a [QueueTrack] from an existing [MediaItem].
  ///
  /// Reads typed values from `item.extras` and falls back to [MediaItem] base
  /// fields for display metadata.
  factory QueueTrack.fromMediaItem(MediaItem item) {
    final extras = item.extras ?? {};
    return QueueTrack(
      videoId: extras['videoId'] as String? ?? item.id,
      url: extras['url'] as String?,
      needsUrl: extras['needsUrl'] == true,
      isVideo: extras['isVideo'] == true,
      isExplicit: extras['isExplicit'] == true,
      artistId: extras['artistId'] as String?,
      albumId: extras['albumId'] as String?,
      viewCount: extras['viewCount'] as int?,
      publishDate: extras['publishDate'] as String?,
      title: item.title,
      artist: item.artist,
      album: item.album,
      duration: item.duration,
      artUri: item.artUri,
    );
  }

  /// Converts this [QueueTrack] back to a [MediaItem].
  ///
  /// Preserves the base [MediaItem] fields (`id`, `title`, `artist`, `album`,
  /// `duration`, `artUri`) and replaces the extras map with typed values.
  /// Queue-management keys (`section`, `queueId`) from the original extras
  /// are preserved if present.
  MediaItem toMediaItem(MediaItem base) {
    final existingExtras = base.extras ?? {};
    final extras = _buildExtras();

    // Preserve queue-management keys that are not part of QueueTrack.
    if (existingExtras.containsKey('section')) {
      extras['section'] = existingExtras['section'];
    }
    if (existingExtras.containsKey('queueId')) {
      extras['queueId'] = existingExtras['queueId'];
    }

    return base.copyWith(extras: extras);
  }

  /// Creates a fresh [MediaItem] from this [QueueTrack] with no base item.
  ///
  /// Uses the display fields stored on this [QueueTrack] to populate the
  /// [MediaItem]. Use when constructing a brand-new [MediaItem] (e.g. from
  /// use cases or DB restore) where there is no pre-existing [MediaItem].
  MediaItem toFreshMediaItem() {
    return MediaItem(
      id: videoId,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
      extras: _buildExtras(),
    );
  }

  Map<String, dynamic> _buildExtras() {
    final extras = <String, dynamic>{
      'videoId': videoId,
      'isVideo': isVideo,
      'isExplicit': isExplicit,
    };

    if (url != null) {
      extras['url'] = url;
    } else if (needsUrl) {
      extras['needsUrl'] = true;
    }

    if (artistId != null) extras['artistId'] = artistId;
    if (albumId != null) extras['albumId'] = albumId;
    if (viewCount != null) extras['viewCount'] = viewCount;
    if (publishDate != null) extras['publishDate'] = publishDate;

    return extras;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueTrack &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          url == other.url &&
          needsUrl == other.needsUrl &&
          isVideo == other.isVideo &&
          isExplicit == other.isExplicit &&
          artistId == other.artistId &&
          albumId == other.albumId &&
          viewCount == other.viewCount &&
          publishDate == other.publishDate;

  @override
  int get hashCode => Object.hash(
    videoId,
    url,
    needsUrl,
    isVideo,
    isExplicit,
    artistId,
    albumId,
    viewCount,
    publishDate,
  );

  @override
  String toString() =>
      'QueueTrack(videoId: $videoId, isVideo: $isVideo, '
      'needsUrl: $needsUrl, hasUrl: ${url != null})';
}
