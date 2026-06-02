@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/remote/ytmusic_datasource.dart';

void main() {
  late YtmusicDatasource datasource;

  setUp(() {
    datasource = YtmusicDatasource();
  });

  group('YtmusicDatasource (live network)', () {
    test('initialize completes without error', () async {
      await expectLater(datasource.initialize(), completes);
      expect(datasource.isInitialized, isTrue);
    });

    test('searchSongs returns non-empty results', () async {
      await datasource.initialize();
      final results = await datasource.searchSongs('test');
      expect(results, isNotEmpty);
      expect(results.any((result) => result.videoId.isNotEmpty), isTrue);
      expect(
        results.firstWhere((result) => result.videoId.isNotEmpty).name,
        isNotEmpty,
      );
    });

    test('searchArtists returns non-empty results', () async {
      await datasource.initialize();
      final results = await datasource.searchArtists('test');
      expect(results, isNotEmpty);
    });

    test('getSearchSuggestions returns suggestions', () async {
      await datasource.initialize();
      final results = await datasource.getSearchSuggestions('test');
      expect(results, isNotEmpty);
    });

    test('reinitialize with different gl/hl works', () async {
      await datasource.initialize(gl: 'US', hl: 'en');
      expect(datasource.isInitialized, isTrue);

      await datasource.reinitialize(gl: 'IT', hl: 'it');
      expect(datasource.isInitialized, isTrue);

      final results = await datasource.searchSongs('test');
      expect(results, isNotEmpty);
      expect(results.any((result) => result.videoId.isNotEmpty), isTrue);
    });
  });
}
