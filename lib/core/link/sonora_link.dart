import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/platform_utils.dart';

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

/// Result of [shareSonoraLink].
enum SonoraShareResult {
  /// Shared via the platform share sheet ([SharePlus]).
  shared,

  /// Copied to the clipboard (Linux desktop).
  copied,
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

/// Builds a one-line caption for share text, or `null` when there is no title.
String? buildSonoraShareCaption({String? title, String? subtitle}) {
  final t = title?.trim();
  if (t == null || t.isEmpty) return null;
  final s = subtitle?.trim();
  if (s == null || s.isEmpty) return t;
  return '$t — $s';
}

/// Full share payload: optional caption line + `sonora://` URL.
String formatSonoraShareText(
  SonoraLink target, {
  String? title,
  String? subtitle,
}) {
  final link = buildSonoraLink(target);
  final caption = buildSonoraShareCaption(title: title, subtitle: subtitle);
  if (caption == null) return link;
  return '$caption\n$link';
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

/// Shares a built Sonora link.
///
/// On Linux copies to the clipboard ([SonoraShareResult.copied]) instead of
/// opening a mailto share sheet. Elsewhere uses [SharePlus].
Future<SonoraShareResult> shareSonoraLink(
  SonoraLink target, {
  String? title,
  String? subtitle,
}) async {
  final text = formatSonoraShareText(target, title: title, subtitle: subtitle);

  if (isLinux) {
    await Clipboard.setData(ClipboardData(text: text));
    return SonoraShareResult.copied;
  }

  await SharePlus.instance.share(ShareParams(text: text));
  return SonoraShareResult.shared;
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
