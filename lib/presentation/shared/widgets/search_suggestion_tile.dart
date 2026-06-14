import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchSuggestionTile extends StatelessWidget {
  final String query;
  final bool isHistory;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onInsert;

  const SearchSuggestionTile({
    super.key,
    required this.query,
    this.isHistory = false,
    required this.onTap,
    this.onDelete,
    this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (onDelete != null) {
      trailing = IconButton(
        icon: const Icon(LucideIcons.x, size: 18),
        onPressed: onDelete,
      );
    } else if (onInsert != null) {
      trailing = IconButton(
        icon: const Icon(LucideIcons.arrowUpLeft, size: 18),
        onPressed: onInsert,
      );
    }

    return ListTile(
      leading: Icon(
        isHistory ? LucideIcons.history : LucideIcons.search,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
      title: Text(query, style: Theme.of(context).textTheme.bodyLarge),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
