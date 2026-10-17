import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/usecases/ai/rewrite_spotify_search_query_use_case.dart';

void main() {
  group('RewriteSpotifySearchQueryUseCase.parseRewriteOutput', () {
    test('accepts a plain query line', () {
      expect(
        RewriteSpotifySearchQueryUseCase.parseRewriteOutput(
          'Blinding Lights The Weeknd',
        ),
        'Blinding Lights The Weeknd',
      );
    });

    test('accepts JSON searchQuery', () {
      expect(
        RewriteSpotifySearchQueryUseCase.parseRewriteOutput(
          '{"searchQuery":"Nera Guè"}',
        ),
        'Nera Guè',
      );
    });

    test('strips markdown fences', () {
      expect(
        RewriteSpotifySearchQueryUseCase.parseRewriteOutput(
          '```\nWith or Without You U2\n```',
        ),
        'With or Without You U2',
      );
    });

    test('returns null for empty or oversized output', () {
      expect(RewriteSpotifySearchQueryUseCase.parseRewriteOutput(''), isNull);
      expect(
        RewriteSpotifySearchQueryUseCase.parseRewriteOutput('   '),
        isNull,
      );
      expect(
        RewriteSpotifySearchQueryUseCase.parseRewriteOutput('x' * 201),
        isNull,
      );
    });
  });
}
