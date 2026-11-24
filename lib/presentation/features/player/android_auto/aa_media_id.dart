/// Parsed target for a contextual track tap inside an Android Auto collection.
class AaPlayTarget {
  final String contextKind;
  final String contextId;
  final int index;
  final String videoId;

  const AaPlayTarget({
    required this.contextKind,
    required this.contextId,
    required this.index,
    required this.videoId,
  });
}

/// Parsed collection action (`play`, `shuffle`, `affinity`, `radio`, `pulse_drop`).
class AaActionTarget {
  final String action;
  final String targetKind;
  final String targetId;

  const AaActionTarget({
    required this.action,
    required this.targetKind,
    required this.targetId,
  });
}

/// Parsed Ask Mix reference (`messageId:attachmentIndex`).
class AaAskMixRef {
  final String messageId;
  final int attachmentIndex;

  const AaAskMixRef({required this.messageId, required this.attachmentIndex});

  String get contextId => '$messageId:$attachmentIndex';
}

/// Typed codec for Android Auto browse node and playback media IDs.
abstract final class AaMediaId {
  static const String root = '/';
  static const String recent = 'recent';
  static const String suggested = 'suggested';

  // Top-level fixed tabs
  static const String home = '__home__';
  static const String library = '__library__';
  static const String explore = '__explore__';
  static const String downloads = '__downloads__';

  // Library folders
  static const String favorites = '__liked__';
  static const String playlists = '__playlists__';
  static const String artists = '__artists__';
  static const String albums = '__albums__';
  static const String podcasts = '__podcasts__';
  static const String savedEpisodes = '__saved_episodes__';
  static const String history = '__history__';
  static const String mixes = '__mixes__';

  // Explore folders
  static const String newReleases = '__new_releases__';
  static const String charts = '__charts__';
  static const String moods = '__moods__';
  static const String discover = '__discover__';
  static const String similarArtists = '__similar_artists__';

  // Dynamic prefixes
  static const String homeSectionPrefix = '__home_section__:';
  static const String homeChipPrefix = '__home_chip__:';
  static const String localPlaylistPrefix = '__playlist__:';
  static const String remotePlaylistPrefix = '__home_playlist__:';
  static const String artistPrefix = '__artist__:';
  static const String albumPrefix = '__home_album__:';
  static const String podcastPrefix = '__podcast__:';
  static const String mixPrefix = '__mix__:';
  static const String chartSectionPrefix = '__chart_section__:';
  static const String moodCategoryPrefix = '__mood_cat__:';
  static const String downloadGroupPrefix = '__dl_group__:';
  static const String askMixPrefix = '__ask_mix__:';

  // Contextual playback & actions
  static const String playPath = '__play__';
  static const String actionPrefix = '__action__:';

  // Context kinds for contextual track playback
  static const String ctxAlbum = 'album';
  static const String ctxPlaylist = 'playlist';
  static const String ctxLocalPlaylist = 'local_playlist';
  static const String ctxArtist = 'artist';
  static const String ctxPodcast = 'podcast';
  static const String ctxSavedEpisodes = 'saved_episodes';
  static const String ctxFavorites = 'favorites';
  static const String ctxHistory = 'history';
  static const String ctxMix = 'mix';
  static const String ctxDownloadGroup = 'dl_group';
  static const String ctxDownloads = 'downloads';
  static const String ctxAskMix = 'ask_mix';
  static const String ctxHomeSection = 'home_section';
  static const String ctxDrop = 'drop';

  // Action kinds
  static const String actPlay = 'play';
  static const String actShuffle = 'shuffle';
  static const String actAffinity = 'affinity';
  static const String actRadio = 'radio';
  static const String actPulseDrop = 'pulse_drop';

  static String homeSection(int index) => '$homeSectionPrefix$index';
  static String homeChip(String params) =>
      '$homeChipPrefix${Uri.encodeComponent(params)}';
  static String localPlaylist(int id) => '$localPlaylistPrefix$id';
  static String remotePlaylist(String id) => '$remotePlaylistPrefix$id';
  static String artist(String id) => '$artistPrefix$id';
  static String album(String id) => '$albumPrefix$id';
  static String podcast(String browseId) => '$podcastPrefix$browseId';
  static String mix(String kind) => '$mixPrefix$kind';
  static String chartSection(String key) => '$chartSectionPrefix$key';
  static String moodCategory(String params) =>
      '$moodCategoryPrefix${Uri.encodeComponent(params)}';
  static String downloadGroup(String key) =>
      '$downloadGroupPrefix${Uri.encodeComponent(key)}';
  static String askMix(String messageId, int attachmentIndex) =>
      '$askMixPrefix$messageId:$attachmentIndex';

  static AaAskMixRef? tryParseAskMix(String raw) {
    final value = raw.startsWith(askMixPrefix)
        ? raw.substring(askMixPrefix.length)
        : raw;
    final sep = value.lastIndexOf(':');
    if (sep <= 0) return null;
    final messageId = value.substring(0, sep);
    final attIdx = int.tryParse(value.substring(sep + 1));
    if (messageId.isEmpty || attIdx == null || attIdx < 0) return null;
    return AaAskMixRef(messageId: messageId, attachmentIndex: attIdx);
  }

  static String playTrack({
    required String contextKind,
    required String contextId,
    required int index,
    required String videoId,
  }) {
    return Uri(
      path: playPath,
      queryParameters: {
        'ctx': contextKind,
        'id': contextId,
        'i': '$index',
        'v': videoId,
      },
    ).toString();
  }

  static AaPlayTarget? tryParsePlayTrack(String mediaId) {
    if (!mediaId.startsWith('$playPath?')) return null;
    final uri = Uri.tryParse(mediaId);
    if (uri == null || uri.path != playPath) return null;
    final ctx = uri.queryParameters['ctx'];
    final id = uri.queryParameters['id'];
    final idxRaw = uri.queryParameters['i'];
    final vid = uri.queryParameters['v'];
    if (ctx == null || ctx.isEmpty || vid == null || vid.isEmpty) {
      return null;
    }
    final index = int.tryParse(idxRaw ?? '');
    if (index == null || index < 0) return null;
    return AaPlayTarget(
      contextKind: ctx,
      contextId: id ?? '',
      index: index,
      videoId: vid,
    );
  }

  static String action(String action, String targetKind, String targetId) {
    return '$actionPrefix$action:$targetKind:${Uri.encodeComponent(targetId)}';
  }

  static AaActionTarget? tryParseAction(String mediaId) {
    if (!mediaId.startsWith(actionPrefix)) return null;
    final rest = mediaId.substring(actionPrefix.length);
    final firstSep = rest.indexOf(':');
    if (firstSep <= 0) return null;
    final secondSep = rest.indexOf(':', firstSep + 1);
    if (secondSep <= firstSep + 1) return null;
    final action = rest.substring(0, firstSep);
    final kind = rest.substring(firstSep + 1, secondSep);
    final encodedId = rest.substring(secondSep + 1);
    if (action.isEmpty || kind.isEmpty) return null;
    return AaActionTarget(
      action: action,
      targetKind: kind,
      targetId: Uri.decodeComponent(encodedId),
    );
  }
}
