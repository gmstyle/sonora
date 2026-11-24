import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../domain/usecases/home/get_discover_suggestions_use_case.dart';
import '../../../../domain/usecases/home/get_similar_artists_suggestions_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import 'aa_cache.dart';
import 'aa_content_mapper.dart';
import 'aa_content_styles.dart';
import 'aa_media_id.dart';

/// Builds the Android Auto Explore tab (Charts, Moods, New Releases, Discover,
/// Similar Artists) with an offline fallback card linking to Downloads.
class AaExploreBuilder {
  final MusicRepository _musicRepo;
  final AaBrowseCache _cache;
  final GetDiscoverSuggestionsUseCase _discoverUseCase;
  final GetSimilarArtistsSuggestionsUseCase _similarArtistsUseCase;

  AaExploreBuilder({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required this._cache,
  }) : _musicRepo = musicRepo,
       _discoverUseCase = GetDiscoverSuggestionsUseCase(musicRepo, libraryRepo),
       _similarArtistsUseCase = GetSimilarArtistsSuggestionsUseCase(
         musicRepo,
         libraryRepo,
       );

  Future<List<MediaItem>> buildExplore({
    required bool isOffline,
    required AppLocalizations l10n,
  }) async {
    if (isOffline) {
      return [
        MediaItem(
          id: AaMediaId.downloads,
          title: l10n.aaOfflineExploreTitle,
          displaySubtitle: l10n.aaOfflineExploreSubtitle,
          artUri: AaContentStyles.drawableUri('cover_downloads'),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleList,
            playable: AaContentStyles.styleList,
          ),
        ),
      ];
    }

    final items = <MediaItem>[];

    // Fetch top explore sources in parallel, tolerating individual failures.
    final (charts, moods, releases, discover, similar) = await (
      _safe(() => _cache.getCharts()),
      _safe(() => _cache.getMoodCategories()),
      _safe(() => _cache.getNewReleases()),
      _safe(() => _discoverUseCase.execute()),
      _safe(() => _similarArtistsUseCase.execute()),
    ).wait;

    if (charts != null) {
      final preview = charts.videos
          .take(4)
          .map((p) => _chartPlaylistFolder(p, groupTitle: l10n.charts))
          .toList(growable: false);
      if (preview.isNotEmpty) {
        items.addAll(preview);
      }
      if (charts.videos.length > 4 ||
          (charts.daily?.isNotEmpty ?? false) ||
          (charts.weekly?.isNotEmpty ?? false) ||
          charts.artists.isNotEmpty) {
        items.add(
          MediaItem(
            id: AaMediaId.charts,
            title: l10n.showMore,
            displaySubtitle: l10n.charts,
            artUri: AaContentStyles.drawableUri('ic_aa_explore'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.charts,
            ),
          ),
        );
      }
    }

    if (moods != null) {
      final categories = moods.sections.entries
          .expand((e) => e.value.map((c) => (e.key, c)))
          .take(4)
          .toList(growable: false);
      for (final pair in categories) {
        items.add(
          _moodCategoryFolder(
            pair.$2,
            pair.$1,
            groupTitle: l10n.moodsAndGenres,
          ),
        );
      }
      if (moods.sections.values.fold<int>(0, (n, l) => n + l.length) > 4) {
        items.add(
          MediaItem(
            id: AaMediaId.moods,
            title: l10n.showMore,
            displaySubtitle: l10n.moodsAndGenres,
            artUri: AaContentStyles.drawableUri('ic_sparkle'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.moodsAndGenres,
            ),
          ),
        );
      }
    }

    if (releases != null && releases.albums.isNotEmpty) {
      for (final album in releases.albums.take(4)) {
        items.add(
          AaContentMapper.albumToBrowseItem(
            album,
            groupTitle: l10n.newReleases,
          ),
        );
      }
      if (releases.albums.length > 4 || releases.videos.isNotEmpty) {
        items.add(
          MediaItem(
            id: AaMediaId.newReleases,
            title: l10n.showMore,
            displaySubtitle: l10n.newReleases,
            artUri: AaContentStyles.drawableUri('cover_albums'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.newReleases,
            ),
          ),
        );
      }
    }

    if (discover != null && discover.isNotEmpty) {
      for (final song in discover.take(4)) {
        items.add(_discoverSongToItem(song, groupTitle: l10n.discover));
      }
      if (discover.length > 4) {
        items.add(
          MediaItem(
            id: AaMediaId.discover,
            title: l10n.showMore,
            displaySubtitle: l10n.discover,
            artUri: AaContentStyles.drawableUri('ic_radio'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.discover,
            ),
          ),
        );
      }
    }

    if (similar != null && similar.isNotEmpty) {
      for (final artist in similar.take(4)) {
        items.add(
          AaContentMapper.artistToBrowseItem(
            artist,
            groupTitle: l10n.similarArtists,
          ),
        );
      }
      if (similar.length > 4) {
        items.add(
          MediaItem(
            id: AaMediaId.similarArtists,
            title: l10n.showMore,
            displaySubtitle: l10n.similarArtists,
            artUri: AaContentStyles.drawableUri('cover_artists'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleList,
              groupTitle: l10n.similarArtists,
            ),
          ),
        );
      }
    }

    return items;
  }

  Future<List<MediaItem>> buildNewReleasesChildren() async {
    final result = await _cache.getNewReleases();
    return [
      for (final a in result.albums) AaContentMapper.albumToBrowseItem(a),
      for (final v in result.videos)
        if (v.isPlayable) AaContentMapper.videoToMediaItem(v),
    ];
  }

  Future<List<MediaItem>> buildChartsChildren(AppLocalizations l10n) async {
    final charts = await _cache.getCharts();
    final items = <MediaItem>[];

    void addSection(String key, String title, bool hasContent) {
      if (!hasContent) return;
      items.add(
        MediaItem(
          id: AaMediaId.chartSection(key),
          title: title,
          artUri: AaContentStyles.drawableUri('ic_aa_explore'),
          playable: false,
          extras: AaContentStyles.styleExtras(
            browsable: AaContentStyles.styleGrid,
          ),
        ),
      );
    }

    addSection('videos', l10n.chartVideos, charts.videos.isNotEmpty);
    addSection('daily', l10n.chartDaily, charts.daily?.isNotEmpty ?? false);
    addSection('weekly', l10n.chartWeekly, charts.weekly?.isNotEmpty ?? false);
    addSection('genres', l10n.chartGenres, charts.genres?.isNotEmpty ?? false);
    addSection(
      'languages',
      l10n.chartLanguages,
      charts.languages?.isNotEmpty ?? false,
    );
    addSection('artists', l10n.artists, charts.artists.isNotEmpty);
    return items;
  }

  Future<List<MediaItem>> buildChartSectionChildren(
    String parentMediaId,
  ) async {
    final section = parentMediaId.substring(
      AaMediaId.chartSectionPrefix.length,
    );
    final charts = await _cache.getCharts();
    switch (section) {
      case 'videos':
        return charts.videos.map(_chartPlaylistFolder).toList(growable: false);
      case 'daily':
        return (charts.daily ?? []).map(_chartPlaylistFolder).toList();
      case 'weekly':
        return (charts.weekly ?? []).map(_chartPlaylistFolder).toList();
      case 'genres':
        return (charts.genres ?? []).map(_chartPlaylistFolder).toList();
      case 'languages':
        return (charts.languages ?? []).map(_chartPlaylistFolder).toList();
      case 'artists':
        return charts.artists
            .map(
              (a) => MediaItem(
                id: AaMediaId.artist(a.browseId),
                title: a.title,
                artist: a.subscribers,
                artUri: a.thumbnails.isNotEmpty
                    ? Uri.tryParse(a.thumbnails.last.url)
                    : AaContentStyles.drawableUri('cover_artists'),
                playable: false,
                extras: AaContentStyles.styleExtras(
                  browsable: AaContentStyles.styleGrid,
                ),
              ),
            )
            .toList(growable: false);
      default:
        return const [];
    }
  }

  Future<List<MediaItem>> buildMoodsChildren() async {
    final result = await _cache.getMoodCategories();
    final items = <MediaItem>[];
    for (final entry in result.sections.entries) {
      for (final category in entry.value) {
        items.add(
          _moodCategoryFolder(category, entry.key, groupTitle: entry.key),
        );
      }
    }
    return items;
  }

  Future<List<MediaItem>> buildMoodPlaylistsChildren(
    String parentMediaId,
  ) async {
    final params = Uri.decodeComponent(
      parentMediaId.substring(AaMediaId.moodCategoryPrefix.length),
    );
    final playlists = await _musicRepo.getMoodPlaylists(params);
    return playlists
        .map((p) => AaContentMapper.playlistToBrowseItem(p))
        .toList(growable: false);
  }

  Future<List<MediaItem>> buildDiscoverChildren() async {
    final suggestions = await _discoverUseCase.execute();
    return suggestions.map(_discoverSongToItem).toList(growable: false);
  }

  Future<List<MediaItem>> buildSimilarArtistsChildren() async {
    final similar = await _similarArtistsUseCase.execute();
    return similar
        .map((a) => AaContentMapper.artistToBrowseItem(a))
        .toList(growable: false);
  }

  MediaItem _chartPlaylistFolder(ChartPlaylist playlist, {String? groupTitle}) {
    return MediaItem(
      id: AaMediaId.remotePlaylist(playlist.playlistId),
      title: playlist.title,
      artUri: playlist.thumbnails.isNotEmpty
          ? Uri.tryParse(playlist.thumbnails.last.url)
          : AaContentStyles.drawableUri('cover_playlist'),
      playable: false,
      extras: AaContentStyles.styleExtras(
        browsable: AaContentStyles.styleGrid,
        groupTitle: groupTitle,
      ),
    );
  }

  MediaItem _moodCategoryFolder(
    MoodCategory category,
    String sectionTitle, {
    String? groupTitle,
  }) {
    return MediaItem(
      id: AaMediaId.moodCategory(category.params),
      title: category.title,
      displaySubtitle: sectionTitle,
      artUri: AaContentStyles.drawableUri('ic_sparkle'),
      playable: false,
      extras: AaContentStyles.styleExtras(
        browsable: AaContentStyles.styleCategoryGrid,
        groupTitle: groupTitle,
      ),
    );
  }

  MediaItem _discoverSongToItem(UpNextsDetails song, {String? groupTitle}) {
    final track = QueueTrack(
      videoId: song.videoId,
      needsUrl: true,
      isVideo: song.type == 'VIDEO',
      isExplicit: song.isExplicit,
      title: song.title,
      artist: displayArtists(song.artists),
      duration: Duration(seconds: song.duration),
      artUri: song.thumbnails.isNotEmpty
          ? Uri.tryParse(song.thumbnails.last.url)
          : null,
    );
    return track.toFreshMediaItem(
      additionalExtras: AaContentStyles.styleExtras(
        playable: AaContentStyles.styleList,
        groupTitle: groupTitle,
        isExplicit: song.isExplicit,
      ),
    );
  }

  Future<T?> _safe<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }
}
