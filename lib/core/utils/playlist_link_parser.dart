/// Parsed remote link identity recovered from a legacy playlist description.
class ParsedPlaylistLink {
  final String sourceKind;
  final String remoteId;

  const ParsedPlaylistLink({required this.sourceKind, required this.remoteId});
}

final _youtubeLinkRe = RegExp(
  r'Synced from YouTube \(ID:\s*([^)]+)\)',
  caseSensitive: false,
);
final _spotifyLinkRe = RegExp(
  r'Imported from Spotify \(ID:\s*([^)]+)\)',
  caseSensitive: false,
);

/// Best-effort parse of import descriptions written by older Sonora versions.
ParsedPlaylistLink? parsePlaylistLinkFromDescription(String? description) {
  if (description == null || description.isEmpty) return null;

  final yt = _youtubeLinkRe.firstMatch(description);
  if (yt != null) {
    final id = yt.group(1)?.trim();
    if (id != null && id.isNotEmpty) {
      return ParsedPlaylistLink(sourceKind: 'youtube', remoteId: id);
    }
  }

  final sp = _spotifyLinkRe.firstMatch(description);
  if (sp != null) {
    final id = sp.group(1)?.trim();
    if (id != null && id.isNotEmpty) {
      return ParsedPlaylistLink(sourceKind: 'spotify', remoteId: id);
    }
  }

  return null;
}
