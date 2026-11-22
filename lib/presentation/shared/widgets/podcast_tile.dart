import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';

class PodcastTile extends StatelessWidget {
  const PodcastTile({
    super.key,
    required this.browseId,
    required this.name,
    this.author,
    this.thumbnailUrl,
    this.trailingActions,
    this.onTap,
  });

  final String browseId;
  final String name;
  final String? author;
  final String? thumbnailUrl;
  final List<Widget>? trailingActions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = [
      if (author != null && author!.isNotEmpty) author!,
      l10n.podcasts,
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
      onTap: onTap ?? () => context.push('/podcast/$browseId'),
      onLongPress: () => ContextMenuSheet.showForPodcast(
        context,
        browseId: browseId,
        name: name,
        author: author,
        thumbnailUrl: thumbnailUrl,
      ),
    );
  }
}
