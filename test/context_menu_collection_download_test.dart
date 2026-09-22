import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/album/providers/album_provider.dart';
import 'package:sonora/presentation/features/playlist/providers/playlist_provider.dart';
import 'package:sonora/presentation/features/podcast/providers/podcast_provider.dart';
import 'package:sonora/presentation/providers/action_feedback_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/music_repository_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/shared/widgets/context_menu_sheet.dart';
import 'package:sonora/presentation/shared/widgets/detail_actions_bar.dart';

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakeMusicRepository extends Fake implements MusicRepository {
  @override
  Future<SongFull> getSong(String videoId) async {
    return SongFull(
      type: 'SONG',
      videoId: videoId,
      name: 'Track 1',
      artists: [ArtistBasic(artistId: 'art1', name: 'Artist')],
      duration: 180,
      thumbnails: const [],
      formats: const [],
      adaptiveFormats: const [],
    );
  }
}

List _songMenuOverrides() => [
  playerStateProvider.overrideWith(_FakePlayer.new),
  musicRepositoryProvider.overrideWithValue(_FakeMusicRepository()),
  likedSongProvider.overrideWith(
    (ref, id) => Stream<LikedSongModel?>.value(null),
  ),
];

class _RecordingDownloads extends DownloadsNotifier {
  final started = <String>[];

  @override
  Map<String, ActiveDownload> build() => {};

  @override
  bool isDownloading(String videoId) => started.contains(videoId);

  @override
  Future<void> startDownload({
    required String videoId,
    required String title,
    required String artist,
    String? artistsJson,
    String? thumbnailUrl,
    String? subdirectory,
    bool isExplicit = false,
    bool isVideo = false,
    String? batchId,
    String? batchName,
    int? batchTotal,
  }) async {
    started.add(videoId);
  }

  @override
  Future<void> deleteDownload(String videoId) async {}
}

AlbumFull _album() {
  final artist = ArtistBasic(artistId: 'art1', name: 'Artist');
  return AlbumFull(
    type: 'ALBUM',
    albumId: 'alb1',
    playlistId: 'pl1',
    name: 'Night Bloom',
    artists: [artist],
    year: 2021,
    thumbnails: const [],
    songs: [
      SongDetailed(
        type: 'SONG',
        videoId: 'vid1',
        name: 'Track 1',
        artists: [artist],
        thumbnails: const [],
      ),
      SongDetailed(
        type: 'SONG',
        videoId: 'vid2',
        name: 'Track 2',
        artists: [artist],
        thumbnails: const [],
      ),
    ],
    relatedReleases: const [],
  );
}

List<VideoDetailed> _videos() {
  final artist = ArtistBasic(artistId: 'art1', name: 'Artist');
  return [
    VideoDetailed(
      type: 'VIDEO',
      videoId: 'vid1',
      name: 'Track 1',
      artists: [artist],
      thumbnails: const [],
    ),
    VideoDetailed(
      type: 'VIDEO',
      videoId: 'vid2',
      name: 'Track 2',
      artists: [artist],
      thumbnails: const [],
    ),
  ];
}

PodcastFull _podcast() {
  return PodcastFull(
    browseId: 'MPSP1',
    name: 'Cool Show',
    author: ArtistBasic(artistId: 'art1', name: 'Host'),
    thumbnails: const [],
    episodes: [
      PodcastEpisode(
        videoId: 'ep1',
        browseId: 'epb1',
        name: 'Episode 1',
        thumbnails: const [],
      ),
      PodcastEpisode(
        videoId: 'ep2',
        browseId: 'epb2',
        name: 'Episode 2',
        thumbnails: const [],
      ),
    ],
  );
}

const _omitBusyActions = {
  DetailActionId.play,
  DetailActionId.shuffle,
  DetailActionId.queue,
  DetailActionId.save,
  DetailActionId.share,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpMenu(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) open,
    List extraOverrides = const [],
    List<DownloadModel> existingDownloads = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWithValue(false),
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value(existingDownloads),
          ),
          activeDownloadsProvider.overrideWith(_RecordingDownloads.new),
          ...extraOverrides,
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => open(context),
                      child: const Text('Open'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> tapMenuLabel(WidgetTester tester, String label) async {
    final finder = find.text(label);
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapDownloadAfterFetchCompletes(
    WidgetTester tester, {
    required VoidCallback completeFetch,
  }) async {
    await tapMenuLabel(tester, 'Download');
    expect(find.text('Download'), findsNothing);
    completeFetch();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('album context download enqueues after the sheet is disposed', (
    tester,
  ) async {
    final gate = Completer<AlbumFull>();
    final container = await pumpMenu(
      tester,
      open:
          (context) => ContextMenuSheet.showForAlbum(
            context,
            albumId: 'alb1',
            name: 'Night Bloom',
            artist: 'Artist',
            omitActionIds: _omitBusyActions,
          ),
      extraOverrides: [albumProvider.overrideWith((ref, _) => gate.future)],
    );

    await tapDownloadAfterFetchCompletes(
      tester,
      completeFetch: () => gate.complete(_album()),
    );

    final feedback = container.read(actionFeedbackProvider);
    expect(feedback?.message, isNull);
    final downloads =
        container.read(activeDownloadsProvider.notifier) as _RecordingDownloads;
    expect(downloads.started, ['vid1', 'vid2']);
  });

  testWidgets(
    'playlist context download enqueues after the sheet is disposed',
    (tester) async {
      final gate = Completer<List<VideoDetailed>>();
      final container = await pumpMenu(
        tester,
        open:
            (context) => ContextMenuSheet.showForPlaylist(
              context,
              playlistId: 'PL1',
              name: 'Mix',
              omitActionIds: _omitBusyActions,
            ),
        extraOverrides: [
          playlistVideosProvider.overrideWith((ref, _) => gate.future),
        ],
      );

      await tapDownloadAfterFetchCompletes(
        tester,
        completeFetch: () => gate.complete(_videos()),
      );

      final feedback = container.read(actionFeedbackProvider);
      expect(feedback?.message, isNull);
      final downloads =
          container.read(activeDownloadsProvider.notifier)
              as _RecordingDownloads;
      expect(downloads.started, ['vid1', 'vid2']);
    },
  );

  testWidgets('podcast context download enqueues after the sheet is disposed', (
    tester,
  ) async {
    final gate = Completer<PodcastFull>();
    final container = await pumpMenu(
      tester,
      open:
          (context) => ContextMenuSheet.showForPodcast(
            context,
            browseId: 'MPSP1',
            name: 'Cool Show',
            omitActionIds: _omitBusyActions,
          ),
      extraOverrides: [podcastProvider.overrideWith((ref, _) => gate.future)],
    );

    await tapDownloadAfterFetchCompletes(
      tester,
      completeFetch: () => gate.complete(_podcast()),
    );

    final feedback = container.read(actionFeedbackProvider);
    expect(feedback?.message, isNull);
    final downloads =
        container.read(activeDownloadsProvider.notifier) as _RecordingDownloads;
    expect(downloads.started, ['ep1', 'ep2']);
  });

  testWidgets('song context download enqueues after the sheet is disposed', (
    tester,
  ) async {
    final container = await pumpMenu(
      tester,
      open:
          (context) => ContextMenuSheet.showForSong(
            context,
            videoId: 'vid1',
            title: 'Track 1',
            artist: 'Artist',
            artistId: 'art1',
            albumId: 'alb1',
          ),
      extraOverrides: _songMenuOverrides(),
    );

    await tapMenuLabel(tester, 'Download');
    expect(find.text('Download'), findsNothing);

    final feedback = container.read(actionFeedbackProvider);
    expect(feedback?.message, isNull);
    final downloads =
        container.read(activeDownloadsProvider.notifier) as _RecordingDownloads;
    expect(downloads.started, ['vid1']);
  });

  testWidgets(
    'already-downloaded song re-download uses root context after pop',
    (tester) async {
      final existing = DownloadModel(
        videoId: 'vid1',
        title: 'Track 1',
        artist: 'Artist',
        status: 'completed',
      );
      final container = await pumpMenu(
        tester,
        open:
            (context) => ContextMenuSheet.showForSong(
              context,
              videoId: 'vid1',
              title: 'Track 1',
              artist: 'Artist',
              artistId: 'art1',
              albumId: 'alb1',
            ),
        extraOverrides: _songMenuOverrides(),
        existingDownloads: [existing],
      );

      await tapMenuLabel(tester, 'Downloaded');
      expect(find.text('Already downloaded'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final feedback = container.read(actionFeedbackProvider);
      expect(feedback?.message, isNull);
      final downloads =
          container.read(activeDownloadsProvider.notifier)
              as _RecordingDownloads;
      expect(downloads.started, ['vid1']);
    },
  );
}
