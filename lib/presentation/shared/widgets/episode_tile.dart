import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.videoId,
    required this.name,
    this.podcastName,
    this.podcastBrowseId,
    this.thumbnailUrl,
    this.date,
    this.trailingActions,
    this.onTap,
  });

  final String videoId;
  final String name;
  final String? podcastName;
  final String? podcastBrowseId;
  final String? thumbnailUrl;
  final String? date;
  final List<Widget>? trailingActions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = [
      if (podcastName != null && podcastName!.isNotEmpty)
        podcastName!
      else
        l10n.episodes,
      if (date != null && date!.isNotEmpty) date!,
    ].join(' · ');

    return ListTile(
      leading: ThumbnailWidget(
        imageUrl: thumbnailUrl,
        size: 48,
        shape: ThumbnailShape.rounded,
      ),
      title: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis, maxLines: 1),
      trailing: trailingActions != null && trailingActions!.isNotEmpty
          ? Row(mainAxisSize: MainAxisSize.min, children: trailingActions!)
          : const Icon(LucideIcons.chevronRight),
      onTap: onTap ?? () => context.push('/episode/$videoId'),
      onLongPress: () => ContextMenuSheet.showForEpisode(
        context,
        videoId: videoId,
        name: name,
        podcastName: podcastName,
        podcastBrowseId: podcastBrowseId,
        thumbnailUrl: thumbnailUrl,
        date: date,
        onGoToPodcast: (id) => context.push('/podcast/$id'),
      ),
    );
  }
}
