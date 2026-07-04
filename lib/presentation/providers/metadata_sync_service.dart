import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'library_repository_provider.dart';
import 'music_repository_provider.dart';

final metadataSyncServiceProvider = Provider<MetadataSyncService>((ref) {
  final service = MetadataSyncService(ref);
  // Start the sync process 8 seconds after the provider is initialized (app startup)
  Future.delayed(const Duration(seconds: 8), () {
    service.startSync();
  });
  return service;
});

class MetadataSyncService {
  final Ref _ref;
  bool _isSyncing = false;

  MetadataSyncService(this._ref);

  Future<void> startSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint(
        '[MetadataSyncService] Starting background metadata backfill...',
      );

      // 1. Check connectivity
      final isOnline = await _checkOnlineStatus();
      if (!isOnline) {
        debugPrint(
          '[MetadataSyncService] Device is offline. Aborting metadata backfill.',
        );
        _isSyncing = false;
        return;
      }

      final libraryRepo = _ref.read(libraryRepositoryProvider);
      final musicRepo = _ref.read(musicRepositoryProvider);

      // 2. Fetch batch of missing metadata track IDs
      final videoIds = await libraryRepo.getTrackIdsMissingMetadata(limit: 15);
      if (videoIds.isNotEmpty) {
        debugPrint(
          '[MetadataSyncService] Found ${videoIds.length} tracks missing metadata. Backfilling...',
        );

        // Process each track sequentially with a delay to avoid rate-limiting (429)
        for (final videoId in videoIds) {
          final stillOnline = await _checkOnlineStatus();
          if (!stillOnline) {
            debugPrint(
              '[MetadataSyncService] Device went offline. Stopping track sync.',
            );
            break;
          }

          try {
            debugPrint(
              '[MetadataSyncService] Fetching metadata for videoId: $videoId',
            );

            // Try to fetch song info
            final song = await musicRepo
                .getSong(videoId)
                .timeout(const Duration(seconds: 10));
            await libraryRepo.updateSongMetadata(
              videoId,
              song.duration,
              song.isExplicit,
            );

            debugPrint(
              '[MetadataSyncService] Updated metadata for $videoId (duration: ${song.duration}, explicit: ${song.isExplicit})',
            );
          } catch (e) {
            // If getSong fails, maybe it is a video (non-song), try getVideo
            try {
              final video = await musicRepo
                  .getVideo(videoId)
                  .timeout(const Duration(seconds: 10));
              await libraryRepo.updateSongMetadata(
                videoId,
                video.duration,
                video.isExplicit,
              );
              debugPrint(
                '[MetadataSyncService] Updated video metadata for $videoId (duration: ${video.duration}, explicit: ${video.isExplicit})',
              );
            } catch (innerErr) {
              debugPrint(
                '[MetadataSyncService] Failed to resolve metadata for $videoId: $innerErr',
              );
            }
          }

          // Wait 4 seconds before next request to be gentle on network / API rate limit
          await Future.delayed(const Duration(seconds: 4));
        }
      } else {
        debugPrint('[MetadataSyncService] All tracks have metadata.');
      }

      // 3. Fetch batch of liked albums missing artistId
      final albumIds = await libraryRepo.getAlbumIdsMissingArtistId(limit: 10);
      if (albumIds.isNotEmpty) {
        debugPrint(
          '[MetadataSyncService] Found ${albumIds.length} albums missing artistId. Backfilling...',
        );

        for (final albumId in albumIds) {
          final stillOnline = await _checkOnlineStatus();
          if (!stillOnline) {
            debugPrint(
              '[MetadataSyncService] Device went offline. Stopping album sync.',
            );
            break;
          }

          try {
            debugPrint(
              '[MetadataSyncService] Fetching album info for albumId: $albumId',
            );

            final album = await musicRepo
                .getAlbum(albumId)
                .timeout(const Duration(seconds: 10));

            final artistId = album.artist.artistId;
            if (artistId != null) {
              await libraryRepo.updateAlbumArtistId(albumId, artistId);
              debugPrint(
                '[MetadataSyncService] Updated artistId for album $albumId ($artistId)',
              );
            } else {
              debugPrint(
                '[MetadataSyncService] Album $albumId does not have a valid artistId in API response.',
              );
            }
          } catch (e) {
            debugPrint(
              '[MetadataSyncService] Failed to resolve artistId for album $albumId: $e',
            );
          }

          // Wait 4 seconds before next request
          await Future.delayed(const Duration(seconds: 4));
        }
      } else {
        debugPrint('[MetadataSyncService] All albums have artistId.');
      }

      final remainingTracks = await libraryRepo.getTrackCountMissingMetadata();
      final remainingAlbums = await libraryRepo.getAlbumCountMissingArtistId();
      debugPrint(
        '[MetadataSyncService] Metadata backfill batch completed. Remaining tracks to sync: $remainingTracks, remaining albums: $remainingAlbums',
      );
    } catch (e) {
      debugPrint('[MetadataSyncService] Error during metadata sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _checkOnlineStatus() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}
