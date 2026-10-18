import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/wrapped_narrative.dart';
import 'package:sonora/domain/usecases/ai/generate_wrapped_narrative_use_case.dart';
import 'package:sonora/domain/usecases/ai/wrapped_narrative_parser.dart';

void main() {
  const facts = WrappedFacts(
    locale: 'it',
    totalMinutes: 1200,
    topArtistName: 'Artist A',
    topArtistPlays: 10,
    topSongTitle: 'Song B',
    topSongArtist: 'Artist A',
    topSongPlays: 5,
    peakHourBand: 'evening',
  );

  test('system instruction is single English prompt with language code', () {
    final prompt = wrappedNarrativeSystemInstruction('it');
    expect(prompt, contains('language code "it"'));
    expect(prompt, isNot(contains('"title":"..."')));
    expect(prompt.toLowerCase(), isNot(contains('sei il narratore')));
  });

  test('parser accepts pack JSON', () {
    const raw = '''
{"title":"Sere di fuoco","hook":"Mille minuti di ascolto.","artistLine":"Artist A ti ha accompagnato.","songLine":"Song B in loop.","closing":"Alla prossima."}
''';
    final parsed = const WrappedNarrativeParser().parse(raw);
    expect(parsed, isNotNull);
    expect(parsed!.title, 'Sere di fuoco');
    expect(wrappedNarrativeRejectReason(parsed, facts), isNull);
  });

  test('rejects placeholder dots', () {
    const junk = WrappedNarrative(title: '...', hook: '...', closing: '...');
    expect(wrappedNarrativeRejectReason(junk, facts), 'placeholder_dots');
  });

  test('peak hour band mapping', () {
    final hourly = List<int>.filled(24, 0);
    hourly[20] = 50;
    expect(WrappedFacts.peakHourBandFrom(hourly), 'evening');
  });
}
