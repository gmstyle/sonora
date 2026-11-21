import 'dart:convert';

import 'grounded_llm_result.dart';

/// Closed action identifiers supported by the managed Cloudflare proxy and
/// DeepSeek client routing.
enum AskActionKind {
  chat('chat'),
  mixIntent('mix_intent'),
  searchIntent('search_intent'),
  trackInsights('track_insights'),
  lyricsTranslate('lyrics_translate'),
  wrapped('wrapped'),
  spotifyMatch('spotify_match'),
  pulseDrop('pulse_drop');

  const AskActionKind(this.wireName);

  final String wireName;
}

/// Active backend resolution mode for Sonora Ask.
enum AskBackendMode { proxy, byok, unconfigured }

/// Quota snapshot for the current device/install.
class AskQuotaInfo {
  const AskQuotaInfo({
    required this.remaining,
    required this.limit,
    this.resetAt,
    this.isUnlimited = false,
    this.isConfigured = true,
  });

  factory AskQuotaInfo.unlimited() => const AskQuotaInfo(
    remaining: -1,
    limit: -1,
    isUnlimited: true,
    isConfigured: true,
  );

  factory AskQuotaInfo.unconfigured() => const AskQuotaInfo(
    remaining: 0,
    limit: 0,
    isUnlimited: false,
    isConfigured: false,
  );

  final int remaining;
  final int limit;
  final DateTime? resetAt;
  final bool isUnlimited;
  final bool isConfigured;

  bool get isExhausted => !isUnlimited && isConfigured && remaining <= 0;
}

/// A tool call emitted by the model during Function Calling.
class AskToolCall {
  const AskToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  Map<String, dynamic> toOpenAiJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': jsonEncode(arguments)},
  };
}

/// Result returned from local/catalog tool execution back to the model.
class AskToolResult {
  const AskToolResult({
    required this.toolCallId,
    required this.name,
    required this.contentJson,
    this.isError = false,
  });

  final String toolCallId;
  final String name;
  final String contentJson;
  final bool isError;
}

/// Grounded playable track reference returned by tools and shown in Ask cards.
class AskTrackRef {
  const AskTrackRef({
    required this.videoId,
    required this.title,
    required this.artist,
    this.artistsJson,
    this.durationSec,
    this.thumbnailUrl,
    this.isExplicit = false,
  });

  factory AskTrackRef.fromJson(Map<String, dynamic> json) {
    return AskTrackRef(
      videoId: json['videoId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      artistsJson: json['artistsJson']?.toString(),
      durationSec: (json['durationSec'] as num?)?.toInt(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      isExplicit: json['isExplicit'] == true,
    );
  }

  final String videoId;
  final String title;
  final String artist;
  final String? artistsJson;
  final int? durationSec;
  final String? thumbnailUrl;
  final bool isExplicit;

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'artist': artist,
    if (artistsJson != null) 'artistsJson': artistsJson,
    if (durationSec != null) 'durationSec': durationSec,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    'isExplicit': isExplicit,
  };
}

/// Grounded artist reference returned by tools and shown in Ask discovery cards.
class AskArtistRef {
  const AskArtistRef({
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.reason,
  });

  factory AskArtistRef.fromJson(Map<String, dynamic> json) {
    return AskArtistRef(
      artistId: json['artistId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      reason: json['reason']?.toString(),
    );
  }

  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'artistId': artistId,
    'name': name,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (reason != null) 'reason': reason,
  };
}

/// Interactive rich attachment embedded inside an assistant chat message.
sealed class AskAttachment {
  const AskAttachment();

  String get type;

  Map<String, dynamic> toJson();

  static AskAttachment? fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    switch (type) {
      case 'mix':
        return AskMixAttachment.fromJson(json);
      case 'artists':
        return AskArtistsAttachment.fromJson(json);
      case 'insights':
        return AskInsightsAttachment.fromJson(json);
      case 'playlist_write':
        return AskPlaylistWriteProposal.fromJson(json);
      default:
        return null;
    }
  }

  static List<AskAttachment> decodeList(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => AskAttachment.fromJson(Map<String, dynamic>.from(e)))
          .whereType<AskAttachment>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String? encodeList(List<AskAttachment> attachments) {
    if (attachments.isEmpty) return null;
    return jsonEncode(attachments.map((e) => e.toJson()).toList());
  }
}

class AskMixAttachment extends AskAttachment {
  const AskMixAttachment({
    required this.title,
    this.subtitle,
    required this.tracks,
    this.savedPlaylistId,
  });

  factory AskMixAttachment.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final tracks = rawTracks is List
        ? rawTracks
              .whereType<Map>()
              .map((e) => AskTrackRef.fromJson(Map<String, dynamic>.from(e)))
              .where((t) => t.videoId.isNotEmpty)
              .toList(growable: false)
        : const <AskTrackRef>[];
    return AskMixAttachment(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      tracks: tracks,
      savedPlaylistId: (json['savedPlaylistId'] as num?)?.toInt(),
    );
  }

  final String title;
  final String? subtitle;
  final List<AskTrackRef> tracks;
  final int? savedPlaylistId;

  @override
  String get type => 'mix';

  AskMixAttachment copyWith({int? savedPlaylistId}) => AskMixAttachment(
    title: title,
    subtitle: subtitle,
    tracks: tracks,
    savedPlaylistId: savedPlaylistId ?? this.savedPlaylistId,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'tracks': tracks.map((t) => t.toJson()).toList(growable: false),
    if (savedPlaylistId != null) 'savedPlaylistId': savedPlaylistId,
  };
}

class AskArtistsAttachment extends AskAttachment {
  const AskArtistsAttachment({required this.title, required this.artists});

  factory AskArtistsAttachment.fromJson(Map<String, dynamic> json) {
    final raw = json['artists'];
    final artists = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => AskArtistRef.fromJson(Map<String, dynamic>.from(e)))
              .where((a) => a.artistId.isNotEmpty)
              .toList(growable: false)
        : const <AskArtistRef>[];
    return AskArtistsAttachment(
      title: json['title']?.toString() ?? '',
      artists: artists,
    );
  }

  final String title;
  final List<AskArtistRef> artists;

  @override
  String get type => 'artists';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'artists': artists.map((a) => a.toJson()).toList(growable: false),
  };
}

class AskInsightsAttachment extends AskAttachment {
  const AskInsightsAttachment({
    required this.title,
    required this.bullets,
    this.sources = const [],
  });

  factory AskInsightsAttachment.fromJson(Map<String, dynamic> json) {
    final rawBullets = json['bullets'];
    final bullets = rawBullets is List
        ? rawBullets
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : const <String>[];
    final rawSources = json['sources'];
    final sources = rawSources is List
        ? rawSources
              .whereType<Map>()
              .map(
                (m) => GroundedSource(
                  uri: m['uri']?.toString() ?? '',
                  title: m['title']?.toString(),
                ),
              )
              .where((s) => s.uri.isNotEmpty)
              .toList(growable: false)
        : const <GroundedSource>[];
    return AskInsightsAttachment(
      title: json['title']?.toString() ?? '',
      bullets: bullets,
      sources: sources,
    );
  }

  final String title;
  final List<String> bullets;
  final List<GroundedSource> sources;

  @override
  String get type => 'insights';

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'bullets': bullets,
    'sources': sources
        .map((s) => {'uri': s.uri, if (s.title != null) 'title': s.title})
        .toList(growable: false),
  };
}

/// Safe-Write proposal emitted by `propose_playlist_write`; requires explicit
/// user confirmation before mutating Drift.
class AskPlaylistWriteProposal extends AskAttachment {
  const AskPlaylistWriteProposal({
    required this.operation,
    this.targetPlaylistId,
    required this.playlistName,
    required this.tracks,
    this.status = 'pending',
    this.savedPlaylistId,
  });

  factory AskPlaylistWriteProposal.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final tracks = rawTracks is List
        ? rawTracks
              .whereType<Map>()
              .map((e) => AskTrackRef.fromJson(Map<String, dynamic>.from(e)))
              .where((t) => t.videoId.isNotEmpty)
              .toList(growable: false)
        : const <AskTrackRef>[];
    return AskPlaylistWriteProposal(
      operation: json['operation']?.toString() ?? 'create',
      targetPlaylistId: (json['targetPlaylistId'] as num?)?.toInt(),
      playlistName: json['playlistName']?.toString() ?? '',
      tracks: tracks,
      status: json['status']?.toString() ?? 'pending',
      savedPlaylistId: (json['savedPlaylistId'] as num?)?.toInt(),
    );
  }

  /// `'create'`, `'append'`, or `'remove'`.
  final String operation;
  final int? targetPlaylistId;
  final String playlistName;
  final List<AskTrackRef> tracks;

  /// `'pending'`, `'saved'`, or `'discarded'`.
  final String status;
  final int? savedPlaylistId;

  @override
  String get type => 'playlist_write';

  bool get isPending => status == 'pending';

  AskPlaylistWriteProposal copyWith({String? status, int? savedPlaylistId}) =>
      AskPlaylistWriteProposal(
        operation: operation,
        targetPlaylistId: targetPlaylistId,
        playlistName: playlistName,
        tracks: tracks,
        status: status ?? this.status,
        savedPlaylistId: savedPlaylistId ?? this.savedPlaylistId,
      );

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'operation': operation,
    if (targetPlaylistId != null) 'targetPlaylistId': targetPlaylistId,
    'playlistName': playlistName,
    'tracks': tracks.map((t) => t.toJson()).toList(growable: false),
    'status': status,
    if (savedPlaylistId != null) 'savedPlaylistId': savedPlaylistId,
  };
}

class AskChatMessage {
  const AskChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.attachments = const [],
    this.toolNamesUsed = const [],
    required this.createdAt,
    this.isError = false,
  });

  final String id;
  final String conversationId;

  /// `'user'` or `'assistant'`.
  final String role;
  final String content;
  final List<AskAttachment> attachments;
  final List<String> toolNamesUsed;
  final DateTime createdAt;
  final bool isError;

  bool get isUser => role == 'user';
}

class AskConversationSummary {
  const AskConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.preview,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? preview;
}

class AskProactiveDrop {
  const AskProactiveDrop({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.starterPrompt,
    this.seedId,
    required this.createdAt,
    this.readAt,
    this.dismissedAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String starterPrompt;
  final String? seedId;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;

  bool get isRead => readAt != null;
}

class AskQuotaExceededException implements Exception {
  const AskQuotaExceededException(this.quota, [this.message]);

  final AskQuotaInfo quota;
  final String? message;

  @override
  String toString() =>
      message ??
      'AskQuotaExceededException(remaining=${quota.remaining}, limit=${quota.limit})';
}

class AskNotConfiguredException implements Exception {
  const AskNotConfiguredException([this.message]);

  final String? message;

  @override
  String toString() => message ?? 'AskNotConfiguredException()';
}
