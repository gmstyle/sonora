import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';

final lyricsProvider = FutureProvider.family<TimedLyricsRes?, String>((
  ref,
  videoId,
) async {
  final repo = ref.watch(musicRepositoryProvider);
  final timed = await repo.getTimedLyrics(videoId);
  if (timed != null && timed.timedLyricsData.isNotEmpty) return timed;
  return null;
});

final plainLyricsProvider = FutureProvider.family<String?, String>((
  ref,
  videoId,
) async {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getLyrics(videoId);
});

class LyricsView extends ConsumerWidget {
  final String videoId;
  final Duration? position;

  const LyricsView({super.key, required this.videoId, this.position});

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
              AppLocalizations.of(context)!.lyricsNotAvailable,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      data: (text) {
        if (text == null || text.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.lyricsNotAvailable,
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

class _TimedLyricsView extends StatefulWidget {
  final TimedLyricsRes lyrics;
  final Duration? position;

  const _TimedLyricsView({required this.lyrics, this.position});

  @override
  State<_TimedLyricsView> createState() => _TimedLyricsViewState();
}

class _TimedLyricsViewState extends State<_TimedLyricsView> {
  int _lastActiveIndex = -1;
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(
      widget.lyrics.timedLyricsData.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(covariant _TimedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final data = widget.lyrics.timedLyricsData;
    final posMs = widget.position?.inMilliseconds ?? 0;

    int activeIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].cueRange != null &&
          data[i].cueRange!.startTimeMilliseconds <= posMs) {
        activeIndex = i;
      }
    }

    if (activeIndex != _lastActiveIndex && activeIndex < _keys.length) {
      _lastActiveIndex = activeIndex;
      _scrollToActiveIndex(activeIndex);
    }
  }

  void _scrollToActiveIndex(int index) {
    if (index < 0 || index >= _keys.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _keys[index];
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.lyrics.timedLyricsData;
    final posMs = widget.position?.inMilliseconds ?? 0;

    int activeIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].cueRange != null &&
          data[i].cueRange!.startTimeMilliseconds <= posMs) {
        activeIndex = i;
      }
    }

    if (_keys.length != data.length) {
      _keys = List.generate(data.length, (_) => GlobalKey());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.35,
      ),
      child: Column(
        children: List.generate(data.length, (index) {
          final line = data[index];
          final isActive = index == activeIndex;
          final isPast = index < activeIndex;

          return Container(
            key: _keys[index],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color:
                    isActive
                        ? Theme.of(context).colorScheme.primary
                        : isPast
                        ? Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                        : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              child: Text(line.lyricLine ?? '', textAlign: TextAlign.center),
            ),
          );
        }),
      ),
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
