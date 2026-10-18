import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/errors/youtube_rate_limited_exception.dart';
import 'package:sonora/presentation/features/player/play_error.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('classifies YoutubeRateLimitedException as rateLimited', () {
    expect(
      PlayErrorKind.classify(
        const YoutubeRateLimitedException(Duration(minutes: 15)),
      ),
      PlayErrorKind.rateLimited,
    );
  });

  test('classifies RequestLimitExceededException as rateLimited', () {
    expect(
      PlayErrorKind.classify(RequestLimitExceededException('too many')),
      PlayErrorKind.rateLimited,
    );
  });

  test('legacy message helper detects rate-limit copy', () {
    expect(
      PlayErrorKind.messageLooksLikeRateLimit(
        'Failed to play video: YoutubeRateLimitedException: cool-down',
      ),
      isTrue,
    );
    expect(
      PlayErrorKind.messageLooksLikeRateLimit('SocketException: offline'),
      isFalse,
    );
  });
}
