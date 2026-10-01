import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/artist/artist_releases_screen.dart';
import 'package:sonora/presentation/features/artist/providers/artist_releases_provider.dart';

AlbumDetailed _release(String id, {String name = 'Release'}) {
  return AlbumDetailed(
    type: 'ALBUM',
    albumId: id,
    playlistId: '',
    name: name,
    thumbnails: const [],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ArtistReleaseKind kind,
  required List<AlbumDetailed> releases,
  Locale locale = const Locale('en'),
  String artistName = 'Taylor Swift',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        artistReleasesProvider.overrideWith((ref, key) async => releases),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArtistReleasesScreen(
          artistId: 'artist',
          artistName: artistName,
          kind: kind,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('albums show-all lists the catalog and the count', (
    tester,
  ) async {
    await _pump(
      tester,
      kind: ArtistReleaseKind.albums,
      releases: [_release('MPREb_1', name: '1989')],
    );

    expect(find.text('Albums · Taylor Swift'), findsOneWidget);
    expect(find.text('1 album'), findsOneWidget);
    expect(find.text('1989'), findsOneWidget);
  });

  testWidgets('singles show-all uses the Italian count', (tester) async {
    await _pump(
      tester,
      kind: ArtistReleaseKind.singles,
      locale: const Locale('it'),
      releases: [
        _release('MPREb_1', name: 'Cardigan'),
        _release('MPREb_2', name: 'Exile'),
      ],
    );

    expect(find.text('Singoli · Taylor Swift'), findsOneWidget);
    expect(find.text('2 singoli'), findsOneWidget);
    expect(find.text('Cardigan'), findsOneWidget);
    expect(find.text('Exile'), findsOneWidget);
  });

  testWidgets('empty catalog shows the empty state', (tester) async {
    await _pump(tester, kind: ArtistReleaseKind.albums, releases: const []);

    expect(find.text('No content available'), findsOneWidget);
    expect(find.text('1989'), findsNothing);
  });
}
