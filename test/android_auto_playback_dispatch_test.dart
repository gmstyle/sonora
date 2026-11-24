import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/llm_completion_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/presentation/features/player/android_auto/aa_media_id.dart';
import 'package:sonora/presentation/features/player/android_auto_browser_controller.dart';

class _FakeConnectivity extends Fake implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
}

class _FakePlayVideoIdUseCase extends Fake implements PlayVideoIdUseCase {
  @override
  Future<String> resolveUrl(String videoId) async =>
      'https://stream.example/$videoId.m4a';

  @override
  Future<MediaItem> execute(
    String videoId, {
    bool? isVideoHint,
    bool? isExplicitHint,
  }) async {
    return QueueTrack(
      videoId: videoId,
      title: 'Resolved $videoId',
      artist: 'Artist $videoId',
      url: 'https://stream.example/$videoId.m4a',
      needsUrl: false,
    ).toFreshMediaItem();
  }
}

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  List<LikedSongModel> likedSongs = const [];
  List<DownloadModel> downloads = const [];
  Completer<void>? favoritesGate;

  @override
  Future<List<LikedSongModel>> getAllLikedSongs() async {
    if (favoritesGate != null) {
      await favoritesGate!.future;
    }
    return likedSongs;
  }

  @override
  Future<List<DownloadModel>> getAllDownloads() async => downloads;

  @override
  Future<LikedAlbumModel?> getLikedAlbum(String albumId) async => null;

  @override
  Future<FollowedArtistModel?> getFollowedArtist(String artistId) async => null;

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async => const [];

  @override
  Future<List<LikedPodcastModel>> getAllLikedPodcasts() async => const [];
}

class _FakeMusicRepo extends Fake implements MusicRepository {
  final List<String> searchedQueries = [];
  List<SongDetailed> searchResults = const [];
  List<WatchTrack> watchTracks = const [];
  AlbumFull? album;
  ArtistFull? artist;
  List<SongDetailed> artistSongs = const [];

  @override
  Future<String> resolveAlbumId(String albumId) async => albumId;

  @override
  Future<AlbumFull> getAlbum(String albumId) async => album!;

  @override
  Future<ArtistFull> getArtist(String artistId) async => artist!;

  @override
  Future<List<SongDetailed>> getArtistSongs(String artistId) async =>
      artistSongs;

  @override
  Future<List<SongDetailed>> searchSongs(String query, {int limit = 20}) async {
    searchedQueries.add(query);
    return searchResults;
  }

  @override
  Future<WatchPlaylistResult> getWatchPlaylist({
    String? videoId,
    String? playlistId,
    bool radio = false,
    bool shuffle = false,
  }) async {
    return WatchPlaylistResult(tracks: watchTracks);
  }
}

class _FakeLlmRepo extends Fake implements LlmCompletionRepository {
  bool ready = true;
  bool shouldThrow = false;
  String responseText =
      '{"title":"Night Drive","searchQuery":"synthwave night drive","seedArtists":["Kavinsky"]}';
  int calls = 0;
  AskActionKind? lastAction;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
    AskActionKind action = AskActionKind.chat,
    String locale = 'en',
    String? turnId,
  }) async {
    calls++;
    lastAction = action;
    if (shouldThrow) throw StateError('LLM error');
    return responseText;
  }
}

SongDetailed _song(String id, String name) {
  return SongDetailed(
    type: 'SONG',
    videoId: id,
    name: name,
    artists: [ArtistBasic(name: 'Artist', artistId: 'UC1')],
    album: null,
    duration: 180,
    thumbnails: const [],
  );
}

WatchTrack _watchTrack(String id, String title) {
  return WatchTrack(
    videoId: id,
    title: title,
    artists: [ArtistBasic(name: 'Radio Artist', artistId: 'UC2')],
    duration: 200,
    thumbnails: const [],
  );
}

void main() {
  late _FakeLibraryRepo libraryRepo;
  late _FakeMusicRepo musicRepo;
  late _FakeLlmRepo llmRepo;
  late SharedPreferences prefs;
  late AndroidAutoBrowserController controller;
  late List<(List<MediaItem> items, int initialIndex)> playCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    libraryRepo = _FakeLibraryRepo();
    musicRepo = _FakeMusicRepo();
    llmRepo = _FakeLlmRepo();
    playCalls = [];

    controller = AndroidAutoBrowserController(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: _FakePlayVideoIdUseCase(),
      connectivity: _FakeConnectivity(),
      prefs: prefs,
      llmCompletionRepo: llmRepo,
      userQueue: () => const [],
      upNextQueue: () => const [],
      currentMediaItem: () => null,
      awaitReady: () async {},
      playNow:
          (items, {int initialIndex = 0, bool Function()? shouldAbort}) async {
            if (shouldAbort != null && shouldAbort()) return;
            playCalls.add((items, initialIndex));
          },
    );
  });

  group('AndroidAutoPlaybackDispatcher contextual & cancellation', () {
    test('tapping contextual Favorites track dispatches full queue at initialIndex', () async {
      final now = DateTime(2026, 2, 1);
      libraryRepo.likedSongs = [
        LikedSongModel(
          videoId: 'v0',
          title: 'First',
          artist: 'A',
          addedAt: now.add(const Duration(minutes: 2)),
        ),
        LikedSongModel(
          videoId: 'v1',
          title: 'Second',
          artist: 'B',
          addedAt: now.add(const Duration(minutes: 1)),
        ),
        LikedSongModel(
          videoId: 'v2',
          title: 'Third',
          artist: 'C',
          addedAt: now,
        ),
      ];

      final secondId = AaMediaId.playTrack(
        contextKind: AaMediaId.ctxFavorites,
        contextId: 'all',
        index: 1,
        videoId: 'v1',
      );

      await controller.playFromMediaId(secondId);

      expect(playCalls, hasLength(1));
      final (items, initialIndex) = playCalls.single;
      expect(items.map((e) => e.id).toList(), ['v0', 'v1', 'v2']);
      expect(initialIndex, 1);
    });

    test(
      'rapid second tap cancels stale playFromMediaId before playNow',
      () async {
        final now = DateTime(2026, 2, 1);
        libraryRepo.likedSongs = [
          LikedSongModel(
            videoId: 'v0',
            title: 'Fav 0',
            artist: 'A',
            addedAt: now,
          ),
        ];
        final gate = Completer<void>();
        libraryRepo.favoritesGate = gate;

        final firstTap = controller.playFromMediaId(
          AaMediaId.playTrack(
            contextKind: AaMediaId.ctxFavorites,
            contextId: 'all',
            index: 0,
            videoId: 'v0',
          ),
        );

        // Rapidly tap a direct track while Favorites load is still pending.
        await controller.playFromMediaId('directTrack');
        gate.complete();
        await firstTap;

        expect(playCalls, hasLength(1));
        expect(playCalls.single.$1.single.id, 'directTrack');
      },
    );

    test(
      'ctxAlbum with unplayable row plays exact tapped playable track index',
      () async {
        musicRepo.album = AlbumFull(
          type: 'Album',
          albumId: 'alb1',
          playlistId: 'OLAK_alb1',
          name: 'Mixed Album',
          artists: [ArtistBasic(name: 'Artist', artistId: 'UC1')],
          thumbnails: const [],
          songs: [
            SongDetailed(
              type: 'SONG',
              videoId: 'grey0',
              name: 'Unavailable Track',
              artists: [ArtistBasic(name: 'Artist', artistId: 'UC1')],
              album: AlbumBasic(albumId: 'alb1', name: 'Mixed Album'),
              isPlayable: false,
              thumbnails: const [],
            ),
            _song('p0', 'Playable 0'),
            _song('p1', 'Playable 1'),
          ],
          relatedReleases: const [],
        );

        final children = await controller.getChildren(AaMediaId.album('alb1'));
        final trackItems = children
            .where((e) => AaMediaId.tryParsePlayTrack(e.id) != null)
            .toList(growable: false);
        expect(trackItems.map((e) => e.title).toList(), [
          'Playable 0',
          'Playable 1',
        ]);

        await controller.playFromMediaId(trackItems[1].id);
        expect(playCalls, hasLength(1));
        final (items, initialIndex) = playCalls.single;
        expect(items.map((e) => e.id).toList(), ['p0', 'p1']);
        expect(initialIndex, 1);
      },
    );

    test(
      'ctxArtist plays tapped topSong consistently with artist browse tree',
      () async {
        musicRepo.artist = ArtistFull(
          artistId: 'UC1',
          name: 'Artist',
          type: 'Artist',
          thumbnails: const [],
          topSongs: [_song('top0', 'Top 0'), _song('top1', 'Top 1')],
          topAlbums: const [],
          topSingles: const [],
          topVideos: const [],
          featuredOn: const [],
          similarArtists: const [],
        );
        musicRepo.artistSongs = [_song('other', 'Different Order Song')];

        final children = await controller.getChildren(AaMediaId.artist('UC1'));
        final tapped = children
            .where((e) => AaMediaId.tryParsePlayTrack(e.id) != null)
            .elementAt(1);
        await controller.playFromMediaId(tapped.id);

        expect(playCalls, hasLength(1));
        final (items, initialIndex) = playCalls.single;
        expect(items.map((e) => e.id).toList(), ['top0', 'top1']);
        expect(initialIndex, 1);
      },
    );

    test(
      'offline search results for grouped downloads play exact tapped videoId',
      () async {
        libraryRepo.downloads = [
          const DownloadModel(
            videoId: 'd0',
            title: 'Zebra',
            artist: 'Artist',
            localPath: '/tmp/d0.m4a',
            status: 'completed',
            collectionType: 'album',
            collectionId: 'alb1',
            collectionName: 'Album',
            collectionIndex: 1,
          ),
          const DownloadModel(
            videoId: 'd1',
            title: 'Alpha Match',
            artist: 'Artist',
            localPath: '/tmp/d1.m4a',
            status: 'completed',
            collectionType: 'album',
            collectionId: 'alb1',
            collectionName: 'Album',
            collectionIndex: 0,
          ),
        ];

        final results = await controller.search('Alpha');
        final downloadMatch = results.firstWhere(
          (e) => e.title == 'Alpha Match',
        );
        await controller.playFromMediaId(downloadMatch.id);

        expect(playCalls, hasLength(1));
        expect(playCalls.single.$1.single.id, 'd1');
      },
    );
  });

  group('AndroidAuto Hybrid Ask voice search', () {
    test('descriptive >= 4 word voice query triggers Ask mixIntent and plays radio', () async {
      musicRepo.searchResults = [_song('seed1', 'Nightcall')];
      musicRepo.watchTracks = [
        _watchTrack('seed1', 'Nightcall'),
        _watchTrack('r2', 'Turbo'),
      ];

      await controller.playFromSearch(
        'play chill night driving synthwave music',
      );

      expect(llmRepo.calls, 1);
      expect(llmRepo.lastAction, AskActionKind.mixIntent);
      expect(musicRepo.searchedQueries, ['synthwave night drive']);
      expect(playCalls, hasLength(1));
      expect(playCalls.single.$1.map((e) => e.id), contains('r2'));
    });

    test(
      'short query or structured focus bypasses Ask and runs standard search',
      () async {
        musicRepo.searchResults = [_song('s1', 'Short Song')];

        await controller.playFromSearch('Daft Punk');
        expect(llmRepo.calls, 0);
        expect(musicRepo.searchedQueries.last, 'Daft Punk');

        await controller.playFromSearch('something with four words', const {
          'android.intent.extra.focus': 'vnd.android.cursor.item/song',
        });
        expect(llmRepo.calls, 0);
        expect(playCalls, hasLength(2));
      },
    );

    test('LLM failure falls back cleanly to standard catalog search', () async {
      llmRepo.shouldThrow = true;
      musicRepo.searchResults = [_song('fallback1', 'Fallback Song')];

      await controller.playFromSearch(
        'something energetic for the morning commute',
      );

      expect(llmRepo.calls, 1);
      expect(musicRepo.searchedQueries, [
        'something energetic for the morning commute',
      ]);
      expect(playCalls, hasLength(1));
      expect(playCalls.single.$1.single.id, 'fallback1');
    });
  });
}
