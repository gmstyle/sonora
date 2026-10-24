import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
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
          child:
              showTranslated
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
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: pc.subtitle),
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
        final pc = PlayerColors.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              height: 1.8,
              color: pc.titleSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
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
            onPressed:
                loading
                    ? null
                    : () =>
                        ref
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
        onPressed:
            loading
                ? null
                : () {
                  ref
                      .read(lyricsTranslationProvider.notifier)
                      .showTranslated(videoId: videoId, targetLanguage: locale);
                },
        icon:
            loading
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
    final pc = PlayerColors.of(context);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          height: 1.8,
          color: pc.titleSecondary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
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
                        ? PlayerColors.of(context).titlePrimary
                        : isPast
                        ? PlayerColors.of(context).labelMuted
                        : PlayerColors.of(context).subtitle,
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
        color: PlayerColors.of(context).subtitle,
        strokeWidth: 2,
      ),
    );
  }
}
