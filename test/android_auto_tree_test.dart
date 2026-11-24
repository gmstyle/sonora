import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/ask_storage_repository.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/presentation/features/player/android_auto/aa_media_id.dart';
import 'package:sonora/presentation/features/player/android_auto_browser_controller.dart';

class _FakeConnectivity extends Fake implements Connectivity {
  List<ConnectivityResult> results = [ConnectivityResult.wifi];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;
}

class _FakePlayVideoIdUseCase extends Fake implements PlayVideoIdUseCase {}

class _FakeMusicRepo extends Fake implements MusicRepository {
  List<HomeSection> homeSections = const [];

  @override
  Future<BrowseHomeResult> getHome({String? params, String? browseId}) async =>
      BrowseHomeResult(chips: const [], sections: homeSections);

  @override
  Future<ChartsResult> getCharts({String country = 'ZZ'}) async => ChartsResult(
    countries: ChartsCountries(selected: country, options: const []),
    videos: const [],
    artists: const [],
  );

  @override
  Future<MoodCategoriesResult> getMoodCategories() async =>
      MoodCategoriesResult(sections: const {});
}

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  List<LikedSongModel> likedSongs = const [];
  List<LikedAlbumModel> likedAlbums = const [];
  List<FollowedArtistModel> followedArtists = const [];
  List<LocalPlaylistModel> playlists = const [];
  List<LikedPlaylistModel> likedPlaylists = const [];
  List<LikedPodcastModel> likedPodcasts = const [];
  List<LikedEpisodeModel> likedEpisodes = const [];
  List<HistoryModel> history = const [];
  List<DownloadModel> downloads = const [];

  @override
  Future<List<LikedSongModel>> getAllLikedSongs() async => likedSongs;

  @override
  Future<List<LikedSongModel>> getForgottenFavorites({
    int daysLimit = 30,
  }) async => const [];

  @override
  Future<List<LikedAlbumModel>> getAllLikedAlbums() async => likedAlbums;

  @override
  Future<List<FollowedArtistModel>> getAllFollowedArtists() async =>
      followedArtists;

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async => playlists;

  @override
  Future<List<LikedPlaylistModel>> getAllLikedPlaylists() async =>
      likedPlaylists;

  @override
  Future<List<LikedPodcastModel>> getAllLikedPodcasts() async => likedPodcasts;

  @override
  Future<List<LikedEpisodeModel>> getAllLikedEpisodes() async => likedEpisodes;

  @override
  Future<List<HistoryModel>> getRecentHistory({int limit = 50}) async =>
      history.take(limit).toList(growable: false);

  @override
  Future<List<HistoryModel>> getMostPlayedSongs({int limit = 50}) async =>
      const [];

  @override
  Future<List<DownloadModel>> getAllDownloads() async => downloads;
}

class _FakeAskStorageRepo extends Fake implements AskStorageRepository {
  List<AskProactiveDrop> drops = const [];
  List<AskConversationSummary> conversations = const [];
  Map<String, List<AskChatMessage>> messagesByConv = const {};

  @override
  Future<List<AskProactiveDrop>> getActiveDrops() async => drops;

  @override
  Future<List<AskConversationSummary>> getConversations() async =>
      conversations;

  @override
  Future<List<AskChatMessage>> getMessages(String conversationId) async =>
      messagesByConv[conversationId] ?? const [];
}

void main() {
  late _FakeConnectivity connectivity;
  late _FakeMusicRepo musicRepo;
  late _FakeLibraryRepo libraryRepo;
  late _FakeAskStorageRepo askStorageRepo;
  late SharedPreferences prefs;
  late AndroidAutoBrowserController controller;
  bool forcedOffline = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    connectivity = _FakeConnectivity();
    musicRepo = _FakeMusicRepo();
    libraryRepo = _FakeLibraryRepo();
    askStorageRepo = _FakeAskStorageRepo();
    forcedOffline = false;

    controller = AndroidAutoBrowserController(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: _FakePlayVideoIdUseCase(),
      connectivity: connectivity,
      isForcedOffline: () => forcedOffline,
      prefs: prefs,
      askStorageRepo: askStorageRepo,
      userQueue: () => const [],
      upNextQueue: () => const [],
      currentMediaItem: () => null,
      awaitReady: () async {},
      playNow: (
        items, {
        int initialIndex = 0,
        bool Function()? shouldAbort,
      }) async {},
    );
  });

  group('Android Auto browse tree structure', () {
    test('root exposes exactly the 4 fixed tabs with vector icons and no queue tabs', () async {
      final root = await controller.getChildren(AudioService.browsableRootId);

      expect(root.map((e) => e.id).toList(), [
        AaMediaId.home,
        AaMediaId.library,
        AaMediaId.explore,
        AaMediaId.downloads,
      ]);
      expect(root.map((e) => e.artUri.toString()).toList(), [
        'android.resource://com.gmstyle.sonora/drawable/ic_aa_home',
        'android.resource://com.gmstyle.sonora/drawable/ic_aa_library',
        'android.resource://com.gmstyle.sonora/drawable/ic_aa_explore',
        'android.resource://com.gmstyle.sonora/drawable/ic_aa_downloads',
      ]);
      expect(root.any((e) => e.id.startsWith('__queue__')), isFalse);
    });

    test('EXTRA_SUGGESTED returns Coolwalk suggested items', () async {
      libraryRepo.history = [
        HistoryModel(
          id: 1,
          videoId: 'hist1',
          title: 'Recent Song',
          artist: 'Artist A',
          playedAt: DateTime(2026, 1, 2),
          playCount: 3,
        ),
      ];
      libraryRepo.downloads = [
        DownloadModel(
          videoId: 'dl1',
          title: 'Offline Track',
          artist: 'Artist B',
          localPath: '/tmp/dl1.m4a',
          status: 'completed',
        ),
      ];

      final suggested = await controller.getChildren(
        AudioService.browsableRootId,
        const {'android.service.media.extra.SUGGESTED': true},
      );

      expect(suggested, isNotEmpty);
      expect(suggested.any((e) => e.title == 'Recent Song'), isTrue);
    });

    test('Explore returns explicit offline banner card when offline', () async {
      forcedOffline = true;
      final children = await controller.getChildren(AaMediaId.explore);

      expect(children, hasLength(1));
      expect(children.single.id, AaMediaId.downloads);
      expect(children.single.playable, isFalse);
    });

    test('Home offline fallback surfaces downloads, playlists, and history without throwing', () async {
      connectivity.results = [ConnectivityResult.none];
      libraryRepo.downloads = [
        DownloadModel(
          videoId: 'dl1',
          title: 'Local Hit',
          artist: 'Artist X',
          localPath: '/tmp/dl1.m4a',
          status: 'completed',
        ),
      ];
      libraryRepo.playlists = [
        LocalPlaylistModel(
          id: 7,
          name: 'Road Trip',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
      libraryRepo.history = [
        HistoryModel(
          id: 1,
          videoId: 'h1',
          title: 'Last Track',
          artist: 'Artist Y',
          playedAt: DateTime(2026, 1, 2),
          playCount: 1,
        ),
      ];

      final home = await controller.getChildren(AaMediaId.home);
      expect(home, isNotEmpty);
      expect(home.any((e) => e.title == 'Local Hit'), isTrue);
      expect(home.any((e) => e.title == 'Last Track'), isTrue);
      expect(home.any((e) => e.id == AaMediaId.mix('most_played')), isTrue);
    });

    test('Home online includes Pulse Drops & Ask Mixes and Podcasts includes Saved Episodes', () async {
      final now = DateTime(2026, 5, 1);
      libraryRepo.likedEpisodes = [
        LikedEpisodeModel(
          videoId: 'ep1',
          name: 'Deep Dive Ep 1',
          podcastName: 'Tech Cast',
          addedAt: now,
        ),
      ];
      askStorageRepo.drops = [
        AskProactiveDrop(
          id: 'drop1',
          kind: 'theme_mix',
          title: 'Midnight Groove',
          body: 'Late night synthwave picks',
          starterPrompt: 'late night synthwave',
          createdAt: now,
        ),
      ];
      askStorageRepo.conversations = [
        AskConversationSummary(
          id: 'conv1',
          title: 'Driving chat',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      askStorageRepo.messagesByConv = {
        'conv1': [
          AskChatMessage(
            id: 'msg1',
            conversationId: 'conv1',
            role: 'assistant',
            content: 'Here is a mix',
            createdAt: now,
            attachments: const [
              AskMixAttachment(
                title: 'Ask Highway Mix',
                tracks: [
                  AskTrackRef(videoId: 't1', title: 'Cruise', artist: 'Daft'),
                ],
              ),
            ],
          ),
        ],
      };

      final podcastsRoot = await controller.getChildren(AaMediaId.podcasts);
      expect(podcastsRoot.any((e) => e.id == AaMediaId.savedEpisodes), isTrue);

      final home = await controller.getChildren(AaMediaId.home);
      expect(home.any((e) => e.title == 'Midnight Groove'), isTrue);
      expect(home.any((e) => e.title == 'Ask Highway Mix'), isTrue);

      final mixes = await controller.getChildren(AaMediaId.mixes);
      expect(mixes.map((e) => e.id).toList(), [
        AaMediaId.mix('most_played'),
        AaMediaId.mix('recently_played'),
        AaMediaId.mix('forgotten_favorites'),
      ]);
    });

    test(
      'Downloads groups completed albums and singles via buildDownloadGroups',
      () async {
        libraryRepo.downloads = [
          const DownloadModel(
            videoId: 'a1',
            title: 'Track 1',
            artist: 'Band',
            localPath: '/tmp/a1.m4a',
            status: 'completed',
            collectionType: 'album',
            collectionId: 'alb1',
            collectionName: 'Best Album',
            collectionIndex: 0,
          ),
          const DownloadModel(
            videoId: 'a2',
            title: 'Track 2',
            artist: 'Band',
            localPath: '/tmp/a2.m4a',
            status: 'completed',
            collectionType: 'album',
            collectionId: 'alb1',
            collectionName: 'Best Album',
            collectionIndex: 1,
          ),
          const DownloadModel(
            videoId: 's1',
            title: 'Loose Single',
            artist: 'Solo',
            localPath: '/tmp/s1.m4a',
            status: 'completed',
          ),
        ];

        final dlRoot = await controller.getChildren(AaMediaId.downloads);
        expect(
          dlRoot.any(
            (e) =>
                e.id == AaMediaId.downloadGroup('album:alb1') &&
                e.title == 'Best Album',
          ),
          isTrue,
        );
        expect(dlRoot.any((e) => e.title == 'Loose Single'), isTrue);

        final albumChildren = await controller.getChildren(
          AaMediaId.downloadGroup('album:alb1'),
        );
        final trackTitles = albumChildren
            .where((e) => AaMediaId.tryParsePlayTrack(e.id) != null)
            .map((e) => e.title)
            .toList();
        expect(trackTitles, ['Track 1', 'Track 2']);
      },
    );
  });
}
