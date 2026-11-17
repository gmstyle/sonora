import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/errors/youtube_rate_limited_exception.dart';
import 'package:sonora/domain/usecases/player/resolve_lead_track.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('returns lead track when first candidate resolves', () async {
    final result = await resolveLeadTrack(
      ['a', 'b', 'c'],
      0,
      videoIdOf: (id) => id,
      resolveUrl: (id) async => 'https://example.com/$id',
    );

    expect(result.tracks, ['a', 'b', 'c']);
    expect(result.leadIndex, 0);
    expect(result.url, 'https://example.com/a');
  });

  test('skips unplayable first track and advances to next playable', () async {
    final tried = <String>[];
    final result = await resolveLeadTrack(
      ['a', 'b', 'c'],
      0,
      videoIdOf: (id) => id,
      resolveUrl: (id) async {
        tried.add(id);
        if (id == 'a') throw VideoUnplayableException('unplayable');
        return 'https://example.com/$id';
      },
    );

    expect(tried, ['a', 'b']);
    expect(result.tracks, ['b', 'c']);
    expect(result.leadIndex, 0);
    expect(result.url, 'https://example.com/b');
  });

  test('preserves earlier tracks when skipping middle lead track', () async {
    final result = await resolveLeadTrack(
      ['a', 'b', 'c'],
      1,
      videoIdOf: (id) => id,
      resolveUrl: (id) async {
        if (id == 'b') throw VideoUnavailableException('unavailable');
        return 'https://example.com/$id';
      },
    );

    expect(result.tracks, ['a', 'c']);
    expect(result.leadIndex, 1);
    expect(result.url, 'https://example.com/c');
  });

  test('wraps around when trailing lead track is unplayable', () async {
    final result = await resolveLeadTrack(
      ['a', 'b', 'c'],
      2,
      videoIdOf: (id) => id,
      resolveUrl: (id) async {
        if (id == 'c') throw VideoUnplayableException('unplayable');
        return 'https://example.com/$id';
      },
    );

    expect(result.tracks, ['a', 'b']);
    expect(result.leadIndex, 0);
    expect(result.url, 'https://example.com/a');
  });

  test('aborts immediately on network or rate-limit failure', () async {
    final tried = <String>[];
    await expectLater(
      resolveLeadTrack(
        ['a', 'b', 'c'],
        0,
        videoIdOf: (id) => id,
        resolveUrl: (id) async {
          tried.add(id);
          throw const SocketException('offline');
        },
      ),
      throwsA(isA<SocketException>()),
    );
    expect(tried, ['a']);

    tried.clear();
    await expectLater(
      resolveLeadTrack(
        ['a', 'b', 'c'],
        0,
        videoIdOf: (id) => id,
        resolveUrl: (id) async {
          tried.add(id);
          throw YoutubeRateLimitedException('cooldown');
        },
      ),
      throwsA(isA<YoutubeRateLimitedException>()),
    );
    expect(tried, ['a']);
  });

  test('caps attempts at maxSkipAttempts and rethrows last error', () async {
    final tried = <String>[];
    await expectLater(
      resolveLeadTrack(
        ['a', 'b', 'c', 'd', 'e', 'f'],
        0,
        videoIdOf: (id) => id,
        maxSkipAttempts: 3,
        resolveUrl: (id) async {
          tried.add(id);
          throw VideoUnplayableException('unplayable $id');
        },
      ),
      throwsA(isA<VideoUnplayableException>()),
    );
    expect(tried, ['a', 'b', 'c']);
  });
}
