import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/extensions/duration_ext.dart';

void main() {
  group('DurationFormat extension', () {
    test('format() should format durations less than an hour', () {
      expect(const Duration(seconds: 0).format(), '0:00');
      expect(const Duration(seconds: 5).format(), '0:05');
      expect(const Duration(seconds: 59).format(), '0:59');
      expect(const Duration(minutes: 1, seconds: 5).format(), '1:05');
      expect(const Duration(minutes: 59, seconds: 59).format(), '59:59');
    });

    test('format() should format durations more than an hour', () {
      expect(const Duration(hours: 1, minutes: 0, seconds: 0).format(), '1:00:00');
      expect(const Duration(hours: 1, minutes: 2, seconds: 3).format(), '1:02:03');
      expect(const Duration(hours: 10, minutes: 59, seconds: 59).format(), '10:59:59');
      expect(const Duration(hours: 176, minutes: 10, seconds: 0).format(), '176:10:00');
    });

    test('toMinutesSeconds() should still work as before (legacy)', () {
      expect(const Duration(minutes: 5, seconds: 30).toMinutesSeconds(), '05:30');
      expect(const Duration(hours: 1, minutes: 5, seconds: 30).toMinutesSeconds(), '01:05:30');
    });

    test('Regression: User example 176:10', () {
       // If the user meant 176 minutes and 10 seconds:
       final d = const Duration(minutes: 176, seconds: 10);
       expect(d.format(), '2:56:10');
    });
  });
}
