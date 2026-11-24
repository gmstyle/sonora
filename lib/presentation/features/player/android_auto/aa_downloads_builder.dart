import 'package:audio_service/audio_service.dart';

import '../../../../domain/models/download_group.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/utils/download_grouping.dart';
import '../../../../l10n/app_localizations.dart';
import 'aa_content_mapper.dart';
import 'aa_content_styles.dart';
import 'aa_media_id.dart';

/// Builds the grouped Android Auto Downloads tab reusing [groupCompletedDownloads].
class AaDownloadsBuilder {
  final LibraryRepository _libraryRepo;

  AaDownloadsBuilder(this._libraryRepo);

  Future<List<DownloadModel>> getCompletedDownloads() async {
    final all = await _libraryRepo.getAllDownloads();
    return all
        .where((d) => d.status == 'completed' && d.localPath != null)
        .toList(growable: false);
  }

  /// Sorts tracks within a download group by `collectionIndex` ascending,
  /// falling back to `downloadedAt` descending when index metadata is absent.
  static List<DownloadModel> sortGroupTracks(DownloadGroup group) {
    final sorted = List<DownloadModel>.of(group.tracks);
    sorted.sort((a, b) {
      final aIdx = a.collectionIndex;
      final bIdx = b.collectionIndex;
      if (aIdx != null && bIdx != null) return aIdx.compareTo(bIdx);
      if (aIdx != null) return -1;
      if (bIdx != null) return 1;
      return (b.downloadedAt ?? DateTime(0)).compareTo(
        a.downloadedAt ?? DateTime(0),
      );
    });
    return sorted;
  }

  Future<List<DownloadGroup>> getGroups() async {
    final completed = await getCompletedDownloads();
    return groupCompletedDownloads(completed);
  }

  Future<DownloadGroup?> findGroup(String groupKey) async {
    final groups = await getGroups();
    for (final g in groups) {
      if (g.key == groupKey) return g;
    }
    return null;
  }

  Future<List<MediaItem>> buildDownloadsRoot(AppLocalizations l10n) async {
    final groups = await getGroups();
    if (groups.isEmpty) return const [];

    final items = <MediaItem>[
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, 'downloads', 'all'),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, 'downloads', 'all'),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    ];

    for (final group in groups) {
      if (group.kind == DownloadGroupKind.singles) {
        final tracks = sortGroupTracks(group);
        for (var i = 0; i < tracks.length; i++) {
          items.add(
            AaContentMapper.downloadToMediaItem(
              tracks[i],
              index: i,
              groupKey: group.key,
              groupTitle: l10n.aaSingleTracks,
            ),
          );
        }
        continue;
      }

      final sectionTitle = switch (group.kind) {
        DownloadGroupKind.album => l10n.aaDownloadedAlbums,
        DownloadGroupKind.podcast => l10n.aaDownloadedPodcasts,
        DownloadGroupKind.playlist ||
        DownloadGroupKind.localPlaylist ||
        DownloadGroupKind.inferred => l10n.aaDownloadedPlaylists,
        DownloadGroupKind.singles => l10n.aaSingleTracks,
      };
      final fallbackCover = switch (group.kind) {
        DownloadGroupKind.album => 'cover_albums',
        DownloadGroupKind.podcast => 'cover_podcasts',
        _ => 'cover_downloads',
      };
      final thumb = group.thumbnailUrl;
      items.add(
        MediaItem(
          id: AaMediaId.downloadGroup(group.key),
          title: group.name,
          displaySubtitle: l10n.songCount(group.tracks.length),
          artUri: thumb != null
              ? Uri.tryParse(thumb)
              : AaContentStyles.drawableUri(fallbackCover),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleGrid,
            playable: AaContentStyles.styleList,
            groupTitle: sectionTitle,
          ),
        ),
      );
    }

    return items;
  }

  Future<List<MediaItem>> buildGroupChildren(
    String encodedKey,
    AppLocalizations l10n,
  ) async {
    final groupKey = Uri.decodeComponent(encodedKey);
    final group = await findGroup(groupKey);
    if (group == null) return const [];

    final tracks = sortGroupTracks(group);
    return [
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, 'dl_group', groupKey),
        title: l10n.playAll,
        artUri: AaContentStyles.drawableUri('ic_play_arrow'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, 'dl_group', groupKey),
        title: l10n.shufflePlay,
        artUri: AaContentStyles.drawableUri('ic_shuffle'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
      for (var i = 0; i < tracks.length; i++)
        AaContentMapper.downloadToMediaItem(
          tracks[i],
          index: i,
          groupKey: groupKey,
        ),
    ];
  }
}
