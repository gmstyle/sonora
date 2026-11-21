import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/constants/ai_constants.dart';

/// Smoke contract for the DeepSeek Ask configuration constants.
void main() {
  test('DeepSeek Ask constants match managed proxy and API contract', () {
    expect(kDeepSeekModelId, 'deepseek-flash');
    expect(kDeepSeekDirectBaseUrl, 'https://api.deepseek.com');
    expect(kAskDailyCreditLimit, 30);
    expect(kAskMaxToolRounds, greaterThanOrEqualTo(3));
    expect(kAskHistoryWindowMessages, greaterThanOrEqualTo(6));
    expect(kSpotifyAssistBatchSize, 12);
    expect(kAskMixTargetTrackCount, 20);
    expect(kAskTimeout.inSeconds, greaterThanOrEqualTo(30));
  });
}
