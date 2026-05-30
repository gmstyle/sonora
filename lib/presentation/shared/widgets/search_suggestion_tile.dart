import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchSuggestionTile extends StatelessWidget {
  final String query;
  final bool isHistory;
  final VoidCallback onTap;

  const SearchSuggestionTile({
    super.key,
    required this.query,
    this.isHistory = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isHistory ? LucideIcons.history : Icons.search,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(query),
      onTap: onTap,
    );
  }
}
