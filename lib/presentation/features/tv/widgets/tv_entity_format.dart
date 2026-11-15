import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/extensions/stat_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../tv_metrics.dart';

/// Formats a total album/playlist duration like touch entity headers.
String formatTotalDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String? formatTrackDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Compact play-count figure for track rows / cards (null when absent).
String? formatPlayCount(String? playCount) => statFigure(playCount);

/// Artist header stats matching touch `_ArtistStatRow` data.
List<({String value, String label})> artistStatEntries(
  ArtistFull artist,
  AppLocalizations l10n,
) {
  return [
    if (statFigure(artist.subscriberCount) case final value?)
      (value: value, label: l10n.subscribers),
    if (statFigure(artist.monthlyListeners) case final value?)
      (value: value, label: l10n.monthlyListeners),
    if (statFigure(artist.totalViews) case final value?)
      (value: value, label: l10n.totalViews),
  ];
}

/// Compact TV artist stats under the title.
class TvArtistStats extends StatelessWidget {
  final ArtistFull artist;

  const TvArtistStats({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = artistStatEntries(artist, l10n);
    if (stats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final stat in stats)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.value,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: TvColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  stat.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: TvColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Entity-level explicit badge (album / playlist header).
class TvExplicitBadge extends StatelessWidget {
  const TvExplicitBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: TvColors.surfaceButton,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'E',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: TvColors.textSecondary,
        ),
      ),
    );
  }
}
