// Domain-level data models for the library layer.
// These are plain Dart classes with no dependency on Drift or any other
// storage framework. [LibraryRepositoryImpl] is responsible for mapping
// between these models and the corresponding Drift-generated DataClass types.

class LikedSongModel {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final DateTime addedAt;

  const LikedSongModel({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.addedAt,
  });
}

class FollowedArtistModel {
  final String artistId;
  final String name;
  final String? thumbnailUrl;

  const FollowedArtistModel({
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
  });
}

class LikedAlbumModel {
  final String albumId;
  final String name;
  final String artistName;
  final String? thumbnailUrl;
  final int? year;
  final DateTime addedAt;

  const LikedAlbumModel({
    required this.albumId,
    required this.name,
    required this.artistName,
    this.thumbnailUrl,
    this.year,
    required this.addedAt,
  });
}

class LikedPlaylistModel {
  final String playlistId;
  final String name;
  final String? thumbnailUrl;
  final int? videoCount;
  final DateTime addedAt;

  const LikedPlaylistModel({
    required this.playlistId,
    required this.name,
    this.thumbnailUrl,
    this.videoCount,
    required this.addedAt,
  });
}

class LocalPlaylistModel {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;

  const LocalPlaylistModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });
}

class PlaylistEntryModel {
  final int playlistId;
  final String videoId;
  final int position;

  const PlaylistEntryModel({
    required this.playlistId,
    required this.videoId,
    required this.position,
  });
}

class DownloadModel {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? localPath;
  final String? format;
  final int? fileSize;
  final DateTime? downloadedAt;
  final String status;

  const DownloadModel({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.localPath,
    this.format,
    this.fileSize,
    this.downloadedAt,
    required this.status,
  });
}

class HistoryModel {
  final int id;
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final DateTime playedAt;
  final int playCount;

  const HistoryModel({
    required this.id,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.playedAt,
    required this.playCount,
  });
}

class SearchHistoryModel {
  final int id;
  final String query;
  final DateTime searchedAt;

  const SearchHistoryModel({
    required this.id,
    required this.query,
    required this.searchedAt,
  });
}
