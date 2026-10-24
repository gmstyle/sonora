import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/grounded_llm_result.dart';
import 'package:sonora/domain/usecases/ai/track_insights_parser.dart';
import 'package:sonora/domain/usecases/ai/translate_lyrics_use_case.dart';
import 'package:sonora/domain/repositories/llm_completion_repository.dart';

void main() {
  group('TrackInsightsParser', () {
    const parser = TrackInsightsParser();

    test('parses bullets JSON', () {
      const raw = '''
{"bullets":["First fact","Second fact","Third"]}
''';
      final parsed = parser.parse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.bullets, ['First fact', 'Second fact', 'Third']);
    });

    test('strips markdown fence and keeps sources', () {
      const raw = '''
```json
{"bullets":["A"]}
```
''';
      final sources = [
        const GroundedSource(
          uri: 'https://en.wikipedia.org/wiki/A',
          title: 'A',
        ),
      ];
      final parsed = parser.parse(raw, sources: sources);
      expect(parsed!.bullets, ['A']);
      expect(parsed.sources.single.uri, contains('wikipedia'));
    });

    test('returns null for empty bullets', () {
      expect(parser.parse('{"bullets":[]}'), isNull);
      expect(parser.parse('not json'), isNull);
    });
  });

  group('extractGroundedSources', () {
    test('maps unique web chunks', () {
      final raw = {
        'candidates': [
          {
            'groundingMetadata': {
              'groundingChunks': [
                {
                  'web': {
                    'uri': 'https://en.wikipedia.org/wiki/Song',
                    'title': 'Song - Wikipedia',
                  },
                },
                {
                  'web': {
                    'uri': 'https://en.wikipedia.org/wiki/Song',
                    'title': 'dup',
                  },
                },
                {
                  'web': {
                    'uri': 'https://example.com/page',
                    'title': 'Example',
                  },
                },
                {'web': {}},
              ],
            },
          },
        ],
      };

      final sources = extractGroundedSources(raw);
      expect(sources, hasLength(2));
      expect(sources.first.displayTitle, 'Song - Wikipedia');
      expect(sources.last.uri, 'https://example.com/page');
    });

    test('returns empty without metadata', () {
      expect(extractGroundedSources(null), isEmpty);
      expect(extractGroundedSources({'candidates': []}), isEmpty);
      expect(
        extractGroundedSources({
          'candidates': [
            {'groundingMetadata': {}},
          ],
        }),
        isEmpty,
      );
    });
  });

  group('TranslateLyricsUseCase', () {
    test('parses translation JSON and clips input', () async {
      String? seenUser;
      final uc = TranslateLyricsUseCase(
        _FakeLlm(
          onComplete: (user) {
            seenUser = user;
            return '{"translation":"Ciao mondo"}';
          },
        ),
      );

      final long = 'x' * (kTranslateLyricsMaxChars + 50);
      final out = await uc.execute(lyrics: long, targetLanguage: 'it');
      expect(out, 'Ciao mondo');
      expect(seenUser, isNotNull);
      expect(seenUser!.length, lessThan(long.length + 40));
      expect(seenUser, contains('Target language: it'));
    });

    test('returns null for empty lyrics', () async {
      final uc = TranslateLyricsUseCase(_FakeLlm(onComplete: (_) => '{}'));
      expect(await uc.execute(lyrics: '  ', targetLanguage: 'en'), isNull);
    });
  });
}

class _FakeLlm implements LlmCompletionRepository {
  _FakeLlm({required this.onComplete});

  final String Function(String userMessage) onComplete;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) async {
    return onComplete(userMessage);
  }
}
