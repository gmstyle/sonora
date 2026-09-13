import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/album/providers/album_provider.dart';
import 'package:sonora/presentation/features/artist/providers/artist_provider.dart';
import 'package:sonora/presentation/features/player/mini_player_content.dart';
import 'package:sonora/presentation/features/player/nav_now_playing.dart';
import 'package:sonora/presentation/features/player/player_sheet_mobile.dart';
import 'package:sonora/presentation/features/player/widgets/animated_play_pause_icon.dart';
import 'package:sonora/presentation/providers/cast_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/vinyl_artwork.dart';

PlayerState _seed = const PlayerState();

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => _seed;
}

class _ExpandedSidebar extends SidebarCollapsedNotifier {
  @override
  bool build() => false;
}

class _CollapsedSidebar extends SidebarCollapsedNotifier {
  @override
  bool build() => true;
}

class _FakeCast extends CastNotifier {
  @override
  Future<CastState> build() async => CastState();
}

AlbumFull _mockAlbum() {
  final artist = ArtistBasic(name: 'Jah Lil', artistId: 'art1');
  return AlbumFull(
    type: 'ALBUM',
    albumId: 'alb1',
    playlistId: 'pl1',
    name: 'Night Bloom',
    artist: artist,
    year: 2021,
    thumbnails: const [],
    songs: [
      SongDetailed(
        type: 'SONG',
        videoId: 'vid1',
        name: 'Above Water',
        artist: artist,
        thumbnails: const [],
      ),
      SongDetailed(
        type: 'SONG',
        videoId: 'vid2',
        name: 'Other',
        artist: artist,
        thumbnails: const [],
      ),
    ],
    relatedReleases: const [],
  );
}

ArtistFull _mockArtist() {
  return ArtistFull(
    artistId: 'art1',
    name: 'Jah Lil',
    type: 'ARTIST',
    thumbnails: const [],
    topSongs: const [],
    topAlbums: const [],
    topSingles: const [],
    topVideos: const [],
    featuredOn: const [],
    similarArtists: const [],
    subscriberCount: '1.2M',
    description: 'A reggae artist from Jamaica.',
  );
}

void main() {
  final song = MediaItem(id: 'vid1', title: 'Above Water', artist: 'Jah Lil');
  final playing = PlayerState(
    currentSong: song,
    isPlaying: true,
    position: const Duration(minutes: 2, seconds: 32),
    duration: const Duration(minutes: 3, seconds: 30),
  );

  setUp(() {
    _seed = playing;
    SharedPreferences.setMockInitialValues({
      kUseVinylStyleKey: false,
      kReduceEffectsKey: true,
    });
  });

  Future<void> pumpNav(
    WidgetTester tester, {
    required bool expanded,
    AlbumFull? album,
    ArtistFull? artist,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
          if (album != null)
            albumProvider.overrideWith((ref, _) async => album),
          if (artist != null)
            artistProvider.overrideWith((ref, _) async => artist),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: expanded ? 240 : 72,
                child: NavNowPlaying(expanded: expanded),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('idle nav now-playing occupies no space', (tester) async {
    _seed = const PlayerState();
    await pumpNav(tester, expanded: true);
    expect(find.text('Above Water'), findsNothing);
    expect(tester.getSize(find.byType(NavNowPlaying)).height, 0);
  });

  testWidgets('wide sidebar card shows metadata without transport', (
    tester,
  ) async {
    await pumpNav(tester, expanded: true);
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.text('Jah Lil'), findsOneWidget);
    expect(find.text('From the album'), findsNothing);
    expect(find.text('About the artist'), findsNothing);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('collapsed rail disc has no transport row', (tester) async {
    await pumpNav(tester, expanded: false);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('expanded card shows album catalog context', (tester) async {
    final albumSong = MediaItem(
      id: 'vid1',
      title: 'Above Water',
      artist: 'Jah Lil',
      extras: {'videoId': 'vid1', 'albumId': 'alb1'},
    );
    _seed = PlayerState(
      currentSong: albumSong,
      isPlaying: true,
      position: const Duration(minutes: 2, seconds: 32),
      duration: const Duration(minutes: 3, seconds: 30),
    );
    await pumpNav(tester, expanded: true, album: _mockAlbum());
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.text('From the album'), findsOneWidget);
    expect(find.text('Night Bloom'), findsOneWidget);
    expect(find.text('2021 · 2 songs · 1 / 2'), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('expanded card shows artist catalog context', (tester) async {
    final artistSong = MediaItem(
      id: 'vid1',
      title: 'Above Water',
      artist: 'Jah Lil',
      extras: {'videoId': 'vid1', 'artistId': 'art1'},
    );
    _seed = PlayerState(
      currentSong: artistSong,
      isPlaying: true,
      position: const Duration(minutes: 2, seconds: 32),
      duration: const Duration(minutes: 3, seconds: 30),
    );
    await pumpNav(tester, expanded: true, artist: _mockArtist());
    expect(find.text('About the artist'), findsOneWidget);
    expect(find.text('1.2M subscribers'), findsOneWidget);
    expect(find.text('A reggae artist from Jamaica.'), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
  });

  testWidgets('expanded card shows podcast catalog context', (tester) async {
    final episode = MediaItem(
      id: 'ep1',
      title: 'Episode 12',
      artist: 'Cool Podcast',
      extras: {
        'contentType': 'episode',
        'podcastBrowseId': 'MPSP123',
        'publishDate': '2024-03-01',
      },
    );
    _seed = PlayerState(
      currentSong: episode,
      isPlaying: true,
      position: const Duration(minutes: 2),
      duration: const Duration(minutes: 40),
    );
    await pumpNav(tester, expanded: true);
    expect(find.text('From the podcast'), findsOneWidget);
    expect(find.text('Cool Podcast'), findsWidgets);
    expect(find.text('2024-03-01'), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
  });

  testWidgets('collapsed rail does not show catalog context', (tester) async {
    final albumSong = MediaItem(
      id: 'vid1',
      title: 'Above Water',
      artist: 'Jah Lil',
      extras: {'videoId': 'vid1', 'albumId': 'alb1', 'artistId': 'art1'},
    );
    _seed = PlayerState(
      currentSong: albumSong,
      isPlaying: true,
      position: const Duration(minutes: 2, seconds: 32),
      duration: const Duration(minutes: 3, seconds: 30),
    );
    await pumpNav(tester, expanded: false);
    expect(find.text('From the album'), findsNothing);
    expect(find.text('About the artist'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('mobile mini player keeps artwork and play', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PlayerSheetMobile()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
    expect(tester.getSize(find.byType(PlayerSheetMobile)).height, 56);
    expect(
      tester
          .widget<GestureDetector>(
            find
                .descendant(
                  of: find.byType(PlayerSheetMobile),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .behavior,
      HitTestBehavior.opaque,
    );
  });

  testWidgets('wide mini player hides title when sidebar is expanded', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1600, 900)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            sidebarCollapsedProvider.overrideWith(_ExpandedSidebar.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1600, 900)),
              child: Scaffold(
                body: SizedBox(
                  width: 1300,
                  height: 72,
                  child: MiniPlayerContent(
                    currentSong: song,
                    playerState: playing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showSecond,
    );
    expect(find.byType(VinylArtwork), findsNothing);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
  });

  testWidgets('wide collapsed mini player shows title', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1600, 900)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            sidebarCollapsedProvider.overrideWith(_CollapsedSidebar.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1600, 900)),
              child: Scaffold(
                body: SizedBox(
                  width: 1300,
                  height: 72,
                  child: MiniPlayerContent(
                    currentSong: song,
                    playerState: playing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showFirst,
    );
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.text('Jah Lil'), findsOneWidget);
    expect(find.byType(VinylArtwork), findsNothing);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
  });

  testWidgets('tablet mini player shows title without artwork', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 600)),
              child: Scaffold(
                body: SizedBox(
                  width: 720,
                  height: 72,
                  child: MiniPlayerContent(
                    currentSong: song,
                    playerState: playing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.byType(VinylArtwork), findsNothing);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
  });

  testWidgets(
    'pixel tablet landscape desktop mini player does not overflow actions',
    (tester) async {
      // Pixel Tablet AVD landscape is ≥1200dp (wide shell), but the floating
      // bar only spans the content pane: 1280 - 240 sidebar - 48 sheet margins.
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              playerStateProvider.overrideWith(_FakePlayer.new),
              sidebarCollapsedProvider.overrideWith(_ExpandedSidebar.new),
              likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
              castStateProvider.overrideWith(_FakeCast.new),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(size: Size(1280, 800)),
                child: Scaffold(
                  body: SizedBox(
                    width: 991,
                    height: 72,
                    child: MiniPlayerContent(
                      currentSong: song,
                      playerState: playing,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
    },
  );
}
