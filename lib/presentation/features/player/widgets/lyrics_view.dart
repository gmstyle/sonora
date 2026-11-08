import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connectivity_provider.dart';
import '../../../providers/lyrics_translation_provider.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/on_device_llm_provider.dart';
import '../../../shared/widgets/error_retry_widget.dart';

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
    final translation = ref.watch(lyricsTranslationProvider);
    final caps = ref.watch(askCapabilitiesProvider).asData?.value;
    final offline = ref.watch(isOfflineProvider);
    final canTranslate = !offline && (caps?.canPlayerInsights ?? false);

    final showTranslated =
        canTranslate &&
        translation.showTranslation &&
        translation.videoId == videoId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canTranslate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _TranslateAskAction(
              videoId: videoId,
              showTranslation: showTranslated,
              loading:
                  showTranslated &&
                  translation.phase == LyricsTranslationPhase.loading,
            ),
          ),
        if (showTranslated &&
            translation.phase == LyricsTranslationPhase.ready) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _TranslationDisclaimer(),
          ),
        ],
        Expanded(
          child: showTranslated
              ? _TranslatedBody(videoId: videoId, state: translation)
              : timedAsync.when(
                  loading: () => const _LyricsLoading(),
                  error: (_, _) => _buildPlainLyrics(context, fallbackAsync),
                  data: (timed) {
                    if (timed != null) {
                      return _TimedLyricsView(
                        lyrics: timed,
                        position: position,
                      );
                    }
                    return _buildPlainLyrics(context, fallbackAsync);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNotAvailable(BuildContext context) {
    final pc = PlayerColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.micOff, size: 48, color: pc.labelMuted),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.lyricsNotAvailable,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: pc.subtitle),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlainLyrics(
    BuildContext context,
    AsyncValue<String?> fallbackAsync,
  ) {
    return fallbackAsync.when(
      loading: () => const _LyricsLoading(),
      error: (_, _) => _buildNotAvailable(context),
      data: (text) {
        if (text == null || text.isEmpty) {
          return _buildNotAvailable(context);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: _lyricHorizontalPad(constraints.maxWidth),
                vertical: 32,
              ),
              child: Text(
                text,
                style: _lyricStyle(context, constraints.maxWidth),
                textAlign: TextAlign.start,
              ),
            );
          },
        );
      },
    );
  }
}

/// Ask-branded translate control (sparkles = AI), not a segmented control.
class _TranslateAskAction extends ConsumerWidget {
  const _TranslateAskAction({
    required this.videoId,
    required this.showTranslation,
    required this.loading,
  });

  final String videoId;
  final bool showTranslation;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;

    if (showTranslation) {
      return Row(
        children: [
          Icon(LucideIcons.sparkles, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.playerAskTranslateLyrics,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: loading
                ? null
                : () => ref
                      .read(lyricsTranslationProvider.notifier)
                      .showOriginal(),
            child: Text(l10n.playerAskOriginal),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.tonalIcon(
        onPressed: loading
            ? null
            : () {
                ref
                    .read(lyricsTranslationProvider.notifier)
                    .showTranslated(videoId: videoId, targetLanguage: locale);
              },
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : const Icon(LucideIcons.sparkles, size: 18),
        label: Text(l10n.playerAskTranslate),
      ),
    );
  }
}

class _TranslationDisclaimer extends StatelessWidget {
  const _TranslationDisclaimer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(LucideIcons.sparkles, size: 16, color: scheme.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.playerAskAiDisclaimerTitle} — ${l10n.playerAskAiDisclaimerBody}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslatedBody extends ConsumerWidget {
  const _TranslatedBody({required this.videoId, required this.state});

  final String videoId;
  final LyricsTranslationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    if (state.phase == LyricsTranslationPhase.loading) {
      return const _LyricsLoading();
    }

    if (state.phase == LyricsTranslationPhase.error) {
      final message = switch (state.errorKind) {
        LyricsTranslationErrorKind.unavailable => l10n.playerAskCloudRequired,
        LyricsTranslationErrorKind.noLyrics => l10n.playerAskNoLyrics,
        LyricsTranslationErrorKind.empty => l10n.playerAskEmpty,
        LyricsTranslationErrorKind.failed || null => l10n.playerAskFailed,
      };
      return ErrorRetryWidget(
        message: message,
        onRetry: () {
          ref
              .read(lyricsTranslationProvider.notifier)
              .showTranslated(videoId: videoId, targetLanguage: locale);
        },
      );
    }

    final text = state.translation ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: _lyricHorizontalPad(constraints.maxWidth),
            vertical: 32,
          ),
          child: Text(
            text,
            style: _lyricStyle(context, constraints.maxWidth),
            textAlign: TextAlign.start,
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

    if (widget.lyrics.timedLyricsData.length !=
        oldWidget.lyrics.timedLyricsData.length) {
      _keys = List.generate(
        widget.lyrics.timedLyricsData.length,
        (_) => GlobalKey(),
      );
    }

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
          alignment: 0.38,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewport = constraints.maxHeight;
        final pad = viewport.isFinite ? viewport * 0.36 : 120.0;
        final size = _lyricSize(width);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            _lyricHorizontalPad(width),
            pad,
            _lyricHorizontalPad(width),
            pad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(data.length, (index) {
              final line = data[index];
              final text = line.lyricLine?.trim() ?? '';
              final isActive = index == activeIndex;
              final isPast = index < activeIndex;

              if (text.isEmpty) {
                return SizedBox(key: _keys[index], height: size * 0.7);
              }

              return Padding(
                key: _keys[index],
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: _lyricStyle(
                    context,
                    width,
                    active: isActive,
                    past: isPast,
                  ),
                  child: Text(text, textAlign: TextAlign.start),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

double _lyricSize(double width) {
  if (width >= 1200) return 48;
  if (width >= 600) return 36;
  return 30;
}

double _lyricHorizontalPad(double width) => width >= 1200 ? 64 : 8;

TextStyle _lyricStyle(
  BuildContext context,
  double width, {
  bool active = false,
  bool past = false,
}) {
  final colors = PlayerColors.of(context);
  final family = Theme.of(context).textTheme.displaySmall;
  return (family ?? const TextStyle()).copyWith(
    fontSize: _lyricSize(width),
    height: 1.18,
    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
    color: active
        ? colors.titlePrimary
        : past
        ? colors.labelMuted
        : colors.subtitle,
  );
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: PlayerColors.of(context).subtitle,
        strokeWidth: 2,
      ),
    );
  }
}
