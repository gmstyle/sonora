class ReleaseNotesSection {
  final String title;
  final List<String> items;

  const ReleaseNotesSection({required this.title, required this.items});
}

/// Strips GitHub-release boilerplate so the in-app dialog shows only the notes.
String sanitizeReleaseNotes(String body) {
  var text = body.replaceAll('\r\n', '\n');

  final downloads = RegExp(r'^## Downloads\s*$', multiLine: true);
  final downloadSplit = downloads.firstMatch(text);
  if (downloadSplit != null) {
    text = text.substring(0, downloadSplit.start);
  }

  text = text.replaceFirst(
    RegExp(
      r'^\*\*Version:\*\*[^\n]*\n(?:\*\*Build:\*\*[^\n]*\n)?(?:\n*---\n*)?',
    ),
    '',
  );

  text = text.replaceAll(
    RegExp(r'^\*\*Full Changelog\*\*:.*$', multiLine: true),
    '',
  );
  text = text.replaceAll(RegExp(r'^---\s*$', multiLine: true), '');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

List<ReleaseNotesSection> parseReleaseNotes(String body) {
  final sanitized = sanitizeReleaseNotes(body);
  if (sanitized.isEmpty) return const [];

  final sections = <ReleaseNotesSection>[];
  var title = '';
  final items = <String>[];

  void flush() {
    if (title.isEmpty && items.isEmpty) return;
    sections.add(
      ReleaseNotesSection(title: title, items: List<String>.of(items)),
    );
    title = '';
    items.clear();
  }

  for (final raw in sanitized.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      flush();
      title = line.replaceFirst(RegExp(r'^#+\s*'), '');
      continue;
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      items.add(_stripInlineMarkdown(line.substring(2).trim()));
      continue;
    }
    items.add(_stripInlineMarkdown(line));
  }
  flush();
  return sections;
}

String _stripInlineMarkdown(String value) {
  return value.replaceAll('**', '').replaceAll('__', '');
}
