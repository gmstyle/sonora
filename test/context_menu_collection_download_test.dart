import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/album/providers/album_provider.dart';
import 'package:sonora/presentation/features/playlist/providers/playlist_provider.dart';
import 'package:sonora/presentation/features/podcast/providers/podcast_provider.dart';
import 'package:sonora/presentation/providers/action_feedback_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/shared/widgets/context_menu_sheet.dart';
import 'package:sonora/presentation/shared/widgets/detail_actions_bar.dart';

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
    required List extraOverrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOfflineProvider.overrideWithValue(false),
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value(const []),
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

  Future<void> tapDownloadAfterFetchCompletes(
    WidgetTester tester, {
    required VoidCallback completeFetch,
  }) async {
    expect(find.text('Download'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await tester.pump();
    expect(find.text('Download'), findsNothing);
    completeFetch();
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'album context download enqueues after the sheet is disposed',
    (tester) async {
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
        extraOverrides: [
          albumProvider.overrideWith((ref, _) => gate.future),
        ],
      );

      await tapDownloadAfterFetchCompletes(
        tester,
        completeFetch: () => gate.complete(_album()),
      );

      final feedback = container.read(actionFeedbackProvider);
      expect(feedback?.message, isNull);
      final downloads =
          container.read(activeDownloadsProvider.notifier)
              as _RecordingDownloads;
      expect(downloads.started, ['vid1', 'vid2']);
    },
  );

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

  testWidgets(
    'podcast context download enqueues after the sheet is disposed',
    (tester) async {
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
        extraOverrides: [
          podcastProvider.overrideWith((ref, _) => gate.future),
        ],
      );

      await tapDownloadAfterFetchCompletes(
        tester,
        completeFetch: () => gate.complete(_podcast()),
      );

      final feedback = container.read(actionFeedbackProvider);
      expect(feedback?.message, isNull);
      final downloads =
          container.read(activeDownloadsProvider.notifier)
              as _RecordingDownloads;
      expect(downloads.started, ['ep1', 'ep2']);
    },
  );
}
