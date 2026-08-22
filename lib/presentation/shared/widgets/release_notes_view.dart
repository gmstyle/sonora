import 'package:flutter/material.dart';

import '../../../domain/usecases/update/release_changelog.dart';

class ReleaseNotesView extends StatelessWidget {
  final String changelog;

  const ReleaseNotesView({super.key, required this.changelog});

  @override
  Widget build(BuildContext context) {
    final sections = parseReleaseNotes(changelog);
    if (sections.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.4).clamp(
      120.0,
      320.0,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (sections[i].title.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 6),
                  child: Text(
                    sections[i].title,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              for (final item in sections[i].items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: theme.textTheme.bodySmall),
                      Expanded(
                        child: Text(item, style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
