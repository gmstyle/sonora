import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/artist/artist_videos_screen.dart';
import 'package:sonora/presentation/shared/widgets/song_tile.dart';
import 'package:sonora/presentation/shared/widgets/video_card.dart';

VideoDetailed _video(String id, {required String name}) {
  return VideoDetailed(
    type: 'VIDEO',
    videoId: id,
    name: name,
    thumbnails: const [],
  );
}

void main() {
  testWidgets('videos show-all uses a VideoCard grid', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          artistVideosProvider.overrideWith(
            (ref, artistId) async => [
              _video('v1', name: 'Blinding Lights'),
              _video('v2', name: 'Save Your Tears'),
            ],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArtistVideosScreen(
            artistId: 'artist',
            artistName: 'The Weeknd',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Videos · The Weeknd'), findsOneWidget);
    expect(find.text('2 videos'), findsOneWidget);
    expect(find.text('Play all'), findsOneWidget);
    expect(find.text('Blinding Lights'), findsOneWidget);
    expect(find.text('Save Your Tears'), findsOneWidget);
    expect(find.byType(VideoCard), findsNWidgets(2));
    expect(find.byType(SongTile), findsNothing);
  });
}
