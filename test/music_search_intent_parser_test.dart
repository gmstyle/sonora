import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/music_search_intent.dart';
import 'package:sonora/domain/usecases/ai/music_search_intent_parser.dart';

void main() {
  const parser = MusicSearchIntentParser();

  test('parses a clean JSON object', () {
    const raw = '''
{"searchQuery":"italian rock 1990s","mood":"energetic","genres":["italian rock"],"era":"1990s","seedArtists":["Ligabue"],"contentType":"songs"}
''';
    final intent = parser.parse(raw)!;
    expect(intent.searchQuery, 'italian rock 1990s');
    expect(intent.mood, 'energetic');
    expect(intent.genres, ['italian rock']);
    expect(intent.era, '1990s');
    expect(intent.seedArtists, ['Ligabue']);
    expect(intent.contentType, MusicSearchContentType.songs);
    expect(intent.searchFilterIndex, 1);
    expect(intent.displayLabel, contains('energetic'));
    expect(intent.source, MixSource.both);
    expect(intent.energy, MixEnergy.unknown);
    expect(intent.mixMood, MixMood.energetic);
  });

  test('parses mix source and energy', () {
    const raw = '''
{"searchQuery":"calm piano","mood":"calm","energy":"low","source":"history","genres":["piano"],"contentType":"songs"}
''';
    final intent = parser.parse(raw)!;
    expect(intent.source, MixSource.history);
    expect(intent.energy, MixEnergy.low);
    expect(intent.mixMood, MixMood.calm);
  });

  test('parses and sanitizes mix title', () {
    const raw = '''
{"title":"  Chill in treno  ","searchQuery":"chill train","mood":"chill","energy":"medium","contentType":"songs"}
''';
    final intent = parser.parse(raw)!;
    expect(intent.title, 'Chill in treno');
  });

  test('omits empty mix title', () {
    const raw =
        '{"title":"","searchQuery":"chill","mood":"chill","contentType":"songs"}';
    final intent = parser.parse(raw)!;
    expect(intent.title, isNull);
  });

  test('maps liked and catalog aliases to MixSource', () {
    expect(
      parser
          .parse('{"searchQuery":"x","source":"liked","contentType":"songs"}')!
          .source,
      MixSource.history,
    );
    expect(
      parser
          .parse(
            '{"searchQuery":"x","source":"catalog","contentType":"songs"}',
          )!
          .source,
      MixSource.ytm,
    );
  });

  test('strips markdown fences and preamble', () {
    const raw = '''
Sure, here you go:
```json
{"searchQuery":"lofi study beats","contentType":"playlists","genres":["lofi"]}
```
''';
    final intent = parser.parse(raw)!;
    expect(intent.searchQuery, 'lofi study beats');
    expect(intent.contentType, MusicSearchContentType.playlists);
  });

  test('composes searchQuery from genres when missing', () {
    const raw =
        '{"genres":["jazz"],"mood":"calm","era":"1960s","contentType":"any"}';
    final intent = parser.parse(raw)!;
    expect(intent.searchQuery, contains('jazz'));
    expect(intent.searchQuery, contains('1960s'));
  });

  test('returns null for empty or invalid payloads', () {
    expect(parser.parse(''), isNull);
    expect(parser.parse('not json'), isNull);
    expect(parser.parse('{"searchQuery":""}'), isNull);
  });
}
