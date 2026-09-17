import 'dart:convert';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

/// Display credit string via [ArtistBasic.formatNames] (empty → `''`).
String displayArtists(List<ArtistBasic> artists) =>
    ArtistBasic.formatNames(artists);

/// Artists that can be navigated to (non-null [ArtistBasic.artistId]).
List<ArtistBasic> navigableArtists(List<ArtistBasic> artists) => [
  for (final a in artists)
    if (a.artistId != null && a.artistId!.isNotEmpty) a,
];

/// First navigable artist id, or `null` if none.
String? primaryArtistId(List<ArtistBasic> artists) {
  for (final a in artists) {
    final id = a.artistId;
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

/// Encode artists for local persistence. Returns `null` when [artists] has
/// length ≤ 1 so single-credit rows stay identical to today.
String? encodeArtistsJson(List<ArtistBasic> artists) {
  if (artists.length <= 1) return null;
  return jsonEncode([
    for (final a in artists)
      {'name': a.name, if (a.artistId != null) 'artistId': a.artistId},
  ]);
}

/// Decode a previously persisted [encodeArtistsJson] string.
List<ArtistBasic> decodeArtistsJson(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final raw = jsonDecode(json);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          ArtistBasic(
            name: (e['name'] as String?) ?? '',
            artistId: e['artistId'] as String?,
          ),
    ].where((a) => a.name.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

/// Build a one-element list from primary display/id when no JSON list exists.
List<ArtistBasic> artistsFromPrimary({String? artist, String? artistId}) {
  final name = artist?.trim() ?? '';
  if (name.isEmpty && (artistId == null || artistId.isEmpty)) {
    return const [];
  }
  return [
    ArtistBasic(
      name: name.isEmpty ? '' : name,
      artistId: (artistId != null && artistId.isNotEmpty) ? artistId : null,
    ),
  ];
}

/// Resolve artists for context-menu navigation.
///
/// Order: API/passed list → [artistsJson] → primary [artist]/[artistId] →
/// enrichment list (e.g. from [SongFull]).
/// A source with names but no [ArtistBasic.artistId] yields to a later source
/// that has navigable ids, so SongFull enrichment can power Go to Artist.
List<ArtistBasic> resolveArtistsList({
  List<ArtistBasic>? artists,
  String? artistsJson,
  String? artist,
  String? artistId,
  List<ArtistBasic>? enrichment,
}) {
  final sources = <List<ArtistBasic>>[];
  if (artists != null && artists.isNotEmpty) {
    sources.add(artists);
  }
  final fromJson = decodeArtistsJson(artistsJson);
  if (fromJson.isNotEmpty) {
    sources.add(fromJson);
  }
  final fromPrimary = artistsFromPrimary(artist: artist, artistId: artistId);
  if (fromPrimary.isNotEmpty) {
    sources.add(fromPrimary);
  }
  if (enrichment != null && enrichment.isNotEmpty) {
    sources.add(enrichment);
  }
  if (sources.isEmpty) return const [];
  return sources.firstWhere(
    (source) => navigableArtists(source).isNotEmpty,
    orElse: () => sources.first,
  );
}
