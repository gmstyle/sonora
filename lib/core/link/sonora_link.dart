import 'package:share_plus/share_plus.dart';

/// Kinds of in-app destinations that can be shared as `sonora://` links.
enum SonoraLinkKind {
  track,
  episode,
  artist,
  album,
  playlist,
  podcast,
  user,
  browseSection,
}

/// A parsed or buildable Sonora deep link.
class SonoraLink {
  final SonoraLinkKind kind;
  final String id;
  final String? params;
  final String? title;

  const SonoraLink({
    required this.kind,
    required this.id,
    this.params,
    this.title,
  });

  /// GoRouter location for navigate kinds (not used for [SonoraLinkKind.track]).
  String get location {
    switch (kind) {
      case SonoraLinkKind.track:
        return '/track/$id';
      case SonoraLinkKind.episode:
        return '/episode/$id';
      case SonoraLinkKind.artist:
        return '/artist/$id';
      case SonoraLinkKind.album:
        return '/album/$id';
      case SonoraLinkKind.playlist:
        return '/playlist/$id';
      case SonoraLinkKind.podcast:
        return '/podcast/$id';
      case SonoraLinkKind.user:
        return '/user/$id';
      case SonoraLinkKind.browseSection:
        final query = <String, String>{
          if (params != null && params!.isNotEmpty) 'params': params!,
          if (title != null && title!.isNotEmpty) 'title': title!,
        };
        final uri = Uri(path: '/browse-section/$id', queryParameters: query);
        return uri.toString();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is SonoraLink &&
        other.kind == kind &&
        other.id == id &&
        other.params == params &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(kind, id, params, title);

  @override
  String toString() =>
      'SonoraLink(kind: $kind, id: $id, params: $params, title: $title)';
}

/// Builds a `sonora://` URL for [target] using safe URI encoding.
String buildSonoraLink(SonoraLink target) {
  final pathSegments = <String>[_kindPath(target.kind), target.id];
  final queryParameters = <String, String>{
    if (target.kind == SonoraLinkKind.browseSection) ...{
      if (target.params != null && target.params!.isNotEmpty)
        'params': target.params!,
      if (target.title != null && target.title!.isNotEmpty)
        'title': target.title!,
    },
  };

  return Uri(
    scheme: 'sonora',
    host: '',
    pathSegments: pathSegments,
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  ).toString();
}

/// Parses a raw share/argv string into a [SonoraLink], or `null` if invalid.
///
/// Accepts surrounding whitespace/newlines. Rejects non-`sonora` schemes and
/// unknown path kinds.
SonoraLink? parseSonoraLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != 'sonora') return null;

  final segments =
      uri.pathSegments
          .where((s) => s.isNotEmpty)
          .map(Uri.decodeComponent)
          .toList();
  if (segments.length < 2) return null;

  final kind = _kindFromPath(segments.first);
  if (kind == null) return null;

  final id = segments[1];
  if (id.isEmpty) return null;

  if (kind == SonoraLinkKind.browseSection) {
    return SonoraLink(
      kind: kind,
      id: id,
      params: uri.queryParameters['params'],
      title: uri.queryParameters['title'],
    );
  }

  return SonoraLink(kind: kind, id: id);
}

/// Thin [SharePlus] wrapper that shares a built Sonora link.
Future<void> shareSonoraLink(SonoraLink target, {String? textPrefix}) async {
  final link = buildSonoraLink(target);
  final text =
      textPrefix == null || textPrefix.isEmpty ? link : '$textPrefix\n$link';
  await SharePlus.instance.share(ShareParams(text: text));
}

String _kindPath(SonoraLinkKind kind) {
  switch (kind) {
    case SonoraLinkKind.track:
      return 'track';
    case SonoraLinkKind.episode:
      return 'episode';
    case SonoraLinkKind.artist:
      return 'artist';
    case SonoraLinkKind.album:
      return 'album';
    case SonoraLinkKind.playlist:
      return 'playlist';
    case SonoraLinkKind.podcast:
      return 'podcast';
    case SonoraLinkKind.user:
      return 'user';
    case SonoraLinkKind.browseSection:
      return 'browse-section';
  }
}

SonoraLinkKind? _kindFromPath(String path) {
  switch (path) {
    case 'track':
      return SonoraLinkKind.track;
    case 'episode':
      return SonoraLinkKind.episode;
    case 'artist':
      return SonoraLinkKind.artist;
    case 'album':
      return SonoraLinkKind.album;
    case 'playlist':
      return SonoraLinkKind.playlist;
    case 'podcast':
      return SonoraLinkKind.podcast;
    case 'user':
      return SonoraLinkKind.user;
    case 'browse-section':
      return SonoraLinkKind.browseSection;
    default:
      return null;
  }
}
