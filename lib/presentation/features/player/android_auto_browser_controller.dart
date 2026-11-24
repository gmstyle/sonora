import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/ask_storage_repository.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/llm_completion_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import 'android_auto/aa_cache.dart';
import 'android_auto/aa_downloads_builder.dart';
import 'android_auto/aa_explore_builder.dart';
import 'android_auto/aa_home_builder.dart';
import 'android_auto/aa_l10n.dart';
import 'android_auto/aa_library_builder.dart';
import 'android_auto/aa_media_id.dart';
import 'android_auto/aa_playback_dispatcher.dart';
import 'android_auto/aa_search_controller.dart';

/// Facade for Android Auto browse tree, text/voice search, and play-from-media-id.
///
/// Delegates to modular builders under `android_auto/` and does not hold a
/// back-reference to [SonoraAudioHandler].
class AndroidAutoBrowserController {
  final Connectivity _connectivity;
  final bool Function() _isForcedOffline;
  final MediaItem? Function() _currentMediaItem;
  final Future<void> Function() _awaitReady;

  late final AaBrowseCache _cache;
  late final AaDownloadsBuilder _downloadsBuilder;
  late final AaHomeBuilder _homeBuilder;
  late final AaLibraryBuilder _libraryBuilder;
  late final AaExploreBuilder _exploreBuilder;
  late final AaSearchController _searchController;
  late final AaPlaybackDispatcher _dispatcher;

  AndroidAutoBrowserController({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required this._connectivity,
    bool Function()? isForcedOffline,
    SharedPreferences? prefs,
    AskStorageRepository? askStorageRepo,
    LlmCompletionRepository? llmCompletionRepo,
    required List<MediaItem> Function() userQueue,
    required List<MediaItem> Function() upNextQueue,
    required this._currentMediaItem,
    required this._awaitReady,
    required Future<void> Function(
      List<MediaItem> items, {
      int initialIndex,
      bool Function()? shouldAbort,
    })
    playNow,
    Future<void> Function()? resumePlayback,
    Duration cacheTtl = const Duration(minutes: 3),
  }) : _isForcedOffline = isForcedOffline ?? (() => false) {
    _cache = AaBrowseCache(musicRepo: musicRepo, prefs: prefs, ttl: cacheTtl);
    _downloadsBuilder = AaDownloadsBuilder(libraryRepo);
    _homeBuilder = AaHomeBuilder(
      libraryRepo: libraryRepo,
      cache: _cache,
      downloadsBuilder: _downloadsBuilder,
      askStorageRepo: askStorageRepo,
    );
    _libraryBuilder = AaLibraryBuilder(
      libraryRepo: libraryRepo,
      musicRepo: musicRepo,
      prefs: prefs,
      homeBuilder: _homeBuilder,
    );
    _exploreBuilder = AaExploreBuilder(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      cache: _cache,
    );
    _searchController = AaSearchController(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: playVideoIdUseCase,
      downloadsBuilder: _downloadsBuilder,
      llmCompletionRepo: llmCompletionRepo,
      resumePlayback: resumePlayback ?? () async {},
      playNow: (items, {int initialIndex = 0}) =>
          playNow(items, initialIndex: initialIndex),
    );
    _dispatcher = AaPlaybackDispatcher(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: playVideoIdUseCase,
      homeBuilder: _homeBuilder,
      libraryBuilder: _libraryBuilder,
      downloadsBuilder: _downloadsBuilder,
      askStorageRepo: askStorageRepo,
      playNow: playNow,
      playFromSearch: (q, extras) => playFromSearch(q, extras),
    );
  }

  /// Invalidates cached Explore / Home Innertube responses (e.g. account/locale change).
  void invalidateCache() => _cache.clear();

  /// Pure helper for the EXTRA_RECENT browse root (0 or 1 playable item).
  @visibleForTesting
  static List<MediaItem> resumptionChildrenFor(MediaItem? current) {
    if (current == null) return const [];
    return [current];
  }

  Future<bool> _isOffline() async {
    if (_isForcedOffline()) return true;
    final results = await _connectivity.checkConnectivity();
    return results.length == 1 && results.contains(ConnectivityResult.none);
  }

  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final l10n = resolveAaL10n();
    final isRoot =
        parentMediaId == AaMediaId.root ||
        parentMediaId == 'root' ||
        parentMediaId == 'root_id' ||
        parentMediaId.isEmpty;

    try {
      if (parentMediaId == AaMediaId.recent) {
        await _awaitReady();
        return resumptionChildrenFor(_currentMediaItem());
      }

      if (parentMediaId == AaMediaId.suggested ||
          (isRoot &&
              options?['android.service.media.extra.SUGGESTED'] == true)) {
        await _awaitReady();
        return await _homeBuilder.buildSuggested(
          isOffline: await _isOffline(),
          l10n: l10n,
        );
      }

      if (isRoot) return _homeBuilder.buildRoot(l10n);

      switch (parentMediaId) {
        case AaMediaId.home:
          return await _homeBuilder.buildHome(
            isOffline: await _isOffline(),
            l10n: l10n,
          );
        case AaMediaId.library:
          return _libraryBuilder.buildLibraryRoot(l10n);
        case AaMediaId.explore:
          return await _exploreBuilder.buildExplore(
            isOffline: await _isOffline(),
            l10n: l10n,
          );
        case AaMediaId.downloads:
          return await _downloadsBuilder.buildDownloadsRoot(l10n);

        case AaMediaId.favorites:
          return await _libraryBuilder.buildFavoritesChildren(l10n);
        case AaMediaId.playlists:
          return await _libraryBuilder.buildPlaylistFolders(l10n);
        case AaMediaId.artists:
          return await _libraryBuilder.buildArtistFolders(l10n);
        case AaMediaId.albums:
          return await _libraryBuilder.buildLikedAlbumFolders();
        case AaMediaId.podcasts:
          return await _libraryBuilder.buildPodcastRoot(l10n);
        case AaMediaId.savedEpisodes:
          return await _libraryBuilder.buildSavedEpisodesChildren(l10n);
        case AaMediaId.history:
          return await _libraryBuilder.buildHistoryChildren(l10n);
        case AaMediaId.mixes:
          return _homeBuilder.buildSmartMixFolders(l10n);

        case AaMediaId.newReleases:
          return await _exploreBuilder.buildNewReleasesChildren();
        case AaMediaId.charts:
          return await _exploreBuilder.buildChartsChildren(l10n);
        case AaMediaId.moods:
          return await _exploreBuilder.buildMoodsChildren();
        case AaMediaId.discover:
          return await _exploreBuilder.buildDiscoverChildren();
        case AaMediaId.similarArtists:
          return await _exploreBuilder.buildSimilarArtistsChildren();

        default:
          if (parentMediaId.startsWith(AaMediaId.homeSectionPrefix)) {
            return await _homeBuilder.buildHomeSectionChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(AaMediaId.homeChipPrefix)) {
            return await _homeBuilder.buildHomeChipChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(AaMediaId.localPlaylistPrefix)) {
            return await _libraryBuilder.buildLocalPlaylistChildren(
              parentMediaId,
              l10n,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.remotePlaylistPrefix)) {
            return await _libraryBuilder.buildRemotePlaylistChildren(
              parentMediaId,
              l10n,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.artistPrefix)) {
            return await _libraryBuilder.buildArtistChildren(
              parentMediaId,
              l10n,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.albumPrefix)) {
            return await _libraryBuilder.buildAlbumChildren(
              parentMediaId,
              l10n,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.podcastPrefix)) {
            return await _libraryBuilder.buildPodcastChildren(
              parentMediaId,
              l10n,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.mixPrefix)) {
            return await _libraryBuilder.buildMixChildren(parentMediaId, l10n);
          }
          if (parentMediaId.startsWith(AaMediaId.askMixPrefix)) {
            return await _libraryBuilder.buildAskMixChildren(
              parentMediaId,
              l10n,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.chartSectionPrefix)) {
            return await _exploreBuilder.buildChartSectionChildren(
              parentMediaId,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.moodCategoryPrefix)) {
            return await _exploreBuilder.buildMoodPlaylistsChildren(
              parentMediaId,
            );
          }
          if (parentMediaId.startsWith(AaMediaId.downloadGroupPrefix)) {
            final encoded = parentMediaId.substring(
              AaMediaId.downloadGroupPrefix.length,
            );
            return await _downloadsBuilder.buildGroupChildren(encoded, l10n);
          }
          return const [];
      }
    } catch (e, st) {
      dev.log('[AA] getChildren error for "$parentMediaId": $e\n$st');
      return const [];
    }
  }

  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      await _dispatcher.playFromMediaId(mediaId);
    } catch (e, st) {
      dev.log('[AA] playFromMediaId error for "$mediaId": $e\n$st');
    }
  }

  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      return await _searchController.search(
        query,
        isOffline: await _isOffline(),
        l10n: resolveAaL10n(),
      );
    } catch (e, st) {
      dev.log('[AA] search error for "$query": $e\n$st');
      return const [];
    }
  }

  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      await _searchController.playFromSearch(
        query,
        extras: extras,
        isOffline: await _isOffline(),
      );
    } catch (e, st) {
      dev.log('[AA] playFromSearch error for "$query": $e\n$st');
    }
  }
}
