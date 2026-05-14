import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';

final lyricsProvider =
    FutureProvider.family<TimedLyricsRes?, String>((ref, videoId) async {
  final repo = ref.watch(musicRepositoryProvider);
  final timed = await repo.getTimedLyrics(videoId);
  if (timed != null && timed.timedLyricsData.isNotEmpty) return timed;
  return null;
});

final plainLyricsProvider =
    FutureProvider.family<String?, String>((ref, videoId) async {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getLyrics(videoId);
});

class LyricsView extends ConsumerWidget {
  final String videoId;
  final Duration? position;

  const LyricsView({
    super.key,
    required this.videoId,
    this.position,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timedAsync = ref.watch(lyricsProvider(videoId));
    final fallbackAsync = ref.watch(plainLyricsProvider(videoId));

    return timedAsync.when(
      loading: () => const _LyricsLoading(),
      error: (_, _) => _buildPlainLyrics(context, fallbackAsync),
      data: (timed) {
        if (timed != null) {
          return _TimedLyricsView(lyrics: timed, position: position);
        }
        return _buildPlainLyrics(context, fallbackAsync);
      },
    );
  }

  Widget _buildPlainLyrics(
    BuildContext context,
    AsyncValue<String?> fallbackAsync,
  ) {
    return fallbackAsync.when(
      loading: () => const _LyricsLoading(),
      error:
          (_, _) => Center(
            child: Text(
              'Lyrics not available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      data: (text) {
        if (text == null || text.isEmpty) {
          return Center(
            child: Text(
              'Lyrics not available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

class _TimedLyricsView extends StatelessWidget {
  final TimedLyricsRes lyrics;
  final Duration? position;

  const _TimedLyricsView({
    required this.lyrics,
    this.position,
  });

  @override
  Widget build(BuildContext context) {
    final data = lyrics.timedLyricsData;
    final posMs = position?.inMilliseconds ?? 0;

    int activeIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].cueRange != null &&
          data[i].cueRange!.startTimeMilliseconds <= posMs) {
        activeIndex = i;
      }
    }

    return ListView.builder(
      itemCount: data.length,
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.3,
      ),
      itemBuilder: (context, index) {
        final line = data[index];
        final isActive = index == activeIndex;
        final isPast = index < activeIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : isPast
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: Text(
              line.lyricLine ?? '',
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        strokeWidth: 2,
      ),
    );
  }
}
