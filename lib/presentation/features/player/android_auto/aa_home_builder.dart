import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/ask_chat_models.dart';
import '../../../../domain/models/download_group.dart';
import '../../../../domain/repositories/ask_storage_repository.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../l10n/app_localizations.dart';
import 'aa_cache.dart';
import 'aa_content_mapper.dart';
import 'aa_content_styles.dart';
import 'aa_downloads_builder.dart';
import 'aa_media_id.dart';

class AaAskMixEntry {
  final String messageId;
  final int attachmentIndex;
  final AskMixAttachment mix;

  const AaAskMixEntry({
    required this.messageId,
    required this.attachmentIndex,
    required this.mix,
  });

  String get contextId => '$messageId:$attachmentIndex';
}

/// Builds the Android Auto root tabs, Coolwalk suggestions, and Home feed.
class AaHomeBuilder {
  final LibraryRepository _libraryRepo;
  final AaBrowseCache _cache;
  final AaDownloadsBuilder _downloadsBuilder;
  final AskStorageRepository? _askStorageRepo;

  AaHomeBuilder({
    required this._libraryRepo,
    required this._cache,
    required this._downloadsBuilder,
    this._askStorageRepo,
  });

  List<MediaItem> buildRoot(AppLocalizations l10n) {
    return [
      MediaItem(
        id: AaMediaId.home,
        title: l10n.home,
        displaySubtitle: l10n.aaForYouSubtitle,
        artUri: AaContentStyles.drawableUri('ic_aa_home'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleList,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.library,
        title: l10n.library,
        displaySubtitle: l10n.aaYourMusicSubtitle,
        artUri: AaContentStyles.drawableUri('ic_aa_library'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.explore,
        title: l10n.explore,
        displaySubtitle: l10n.aaExploreSubtitle,
        artUri: AaContentStyles.drawableUri('ic_aa_explore'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleList,
          playable: AaContentStyles.styleList,
        ),
      ),
      MediaItem(
        id: AaMediaId.downloads,
        title: l10n.downloads,
        displaySubtitle: l10n.aaDownloadsSubtitle,
        artUri: AaContentStyles.drawableUri('ic_aa_downloads'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleList,
          playable: AaContentStyles.styleList,
        ),
      ),
    ];
  }

  /// Coolwalk `EXTRA_SUGGESTED` quick-launch items (playable & browsable).
  Future<List<MediaItem>> buildSuggested({
    required bool isOffline,
    required AppLocalizations l10n,
  }) async {
    final items = <MediaItem>[];

    final recent = await _libraryRepo.getRecentHistory(limit: 1);
    if (recent.isNotEmpty) {
      items.add(AaContentMapper.historyToMediaItem(recent.first, index: 0));
    }

    if (!isOffline && _askStorageRepo != null) {
      final drops = await _askStorageRepo.getActiveDrops();
      if (drops.isNotEmpty) {
        items.add(_pulseDropToItem(drops.first, l10n));
      }
    }

    items.add(
      MediaItem(
        id: AaMediaId.action(AaMediaId.actShuffle, 'favorites', 'all'),
        title: '${l10n.favorites} · ${l10n.shuffle}',
        artUri: AaContentStyles.drawableUri('cover_favorites'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    );

    items.add(
      MediaItem(
        id: AaMediaId.action(AaMediaId.actPlay, 'mix', 'most_played'),
        title: l10n.mostPlayed,
        artUri: AaContentStyles.drawableUri('cover_most_played'),
        playable: true,
        extras: AaContentStyles.styleExtras(
          playable: AaContentStyles.styleList,
        ),
      ),
    );

    final downloads = await _downloadsBuilder.getCompletedDownloads();
    if (downloads.isNotEmpty) {
      items.add(
        MediaItem(
          id: AaMediaId.action(AaMediaId.actPlay, 'downloads', 'all'),
          title: l10n.downloads,
          artUri: AaContentStyles.drawableUri('cover_downloads'),
          playable: true,
          extras: AaContentStyles.styleExtras(
            playable: AaContentStyles.styleList,
          ),
        ),
      );
    }

    return items.take(6).toList(growable: false);
  }

  Future<List<MediaItem>> buildHome({
    required bool isOffline,
    required AppLocalizations l10n,
  }) async {
    final items = <MediaItem>[];

    // 1. Continue Listening (recent history with full song/episode metadata)
    final history = await _libraryRepo.getRecentHistory(limit: 4);
    for (var i = 0; i < history.length; i++) {
      items.add(
        AaContentMapper.historyToMediaItem(
          history[i],
          index: i,
          groupTitle: l10n.aaContinueListening,
        ),
      );
    }

    // 2. Pulse Drops, recent Ask Mixes, and Local Smart Mixes
    await _addPulseAndMixesGroup(items, isOffline: isOffline, l10n: l10n);

    if (isOffline) {
      await _addOfflineDownloadShortcuts(items, l10n);
      return items;
    }

    // 3. Online: Driving Mood Chips + YTM Personalized Home Shelves
    try {
      final home = await _cache.getHome();
      for (final chip in home.chips.take(6)) {
        if (chip.params.isEmpty) continue;
        items.add(
          MediaItem(
            id: AaMediaId.homeChip(chip.params),
            title: chip.title,
            artUri: AaContentStyles.drawableUri('ic_sparkle'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleCategoryGrid,
              playable: AaContentStyles.styleList,
              groupTitle: l10n.aaMoodsForDrive,
            ),
          ),
        );
      }

      for (var sIdx = 0; sIdx < home.sections.length && sIdx < 4; sIdx++) {
        final section = home.sections[sIdx];
        if (section.contents.isEmpty) continue;
        final mapped = <MediaItem>[];
        for (var i = 0; i < section.contents.length; i++) {
          mapped.addAll(
            AaContentMapper.homeContentToMediaItems(
              section.contents[i],
              groupTitle: section.title,
              playableStyle: AaContentStyles.styleList,
              browsableStyle: AaContentStyles.styleGrid,
              contextKind: AaMediaId.ctxHomeSection,
              contextId: '$sIdx',
              contextIndex: i,
            ),
          );
        }
        if (mapped.isEmpty) continue;
        items.addAll(mapped.take(6));
        if (mapped.length > 6) {
          items.add(
            MediaItem(
              id: AaMediaId.homeSection(sIdx),
              title: l10n.showMore,
              displaySubtitle: section.title,
              artUri: AaContentStyles.drawableUri('ic_aa_explore'),
              playable: false,
              extras: AaContentStyles.styleExtras(
                browsable: AaContentStyles.styleList,
                playable: AaContentStyles.styleList,
                groupTitle: section.title,
              ),
            ),
          );
        }
      }
    } catch (_) {
      await _addOfflineDownloadShortcuts(items, l10n);
    }

    return items;
  }

  Future<void> _addPulseAndMixesGroup(
    List<MediaItem> items, {
    required bool isOffline,
    required AppLocalizations l10n,
  }) async {
    final group = l10n.aaPulseAndMixes;

    if (!isOffline && _askStorageRepo != null) {
      try {
        final drops = await _askStorageRepo.getActiveDrops();
        for (final drop in drops.take(2)) {
          items.add(_pulseDropToItem(drop, l10n, groupTitle: group));
        }

        final mixes = await getRecentAskMixes(limit: 2);
        for (final entry in mixes) {
          items.add(
            MediaItem(
              id: AaMediaId.askMix(entry.messageId, entry.attachmentIndex),
              title: entry.mix.title,
              displaySubtitle: entry.mix.subtitle ?? l10n.aaAskMixSubtitle,
              artUri:
                  _mixArt(entry.mix) ??
                  AaContentStyles.drawableUri('cover_pulse_drops'),
              playable: false,
              extras: AaContentStyles.styleExtras(
                browsable: AaContentStyles.styleGrid,
                playable: AaContentStyles.styleList,
                groupTitle: group,
              ),
            ),
          );
        }
      } catch (_) {}
    }

    items.addAll(buildSmartMixFolders(l10n, groupTitle: group));
  }

  List<MediaItem> buildSmartMixFolders(
    AppLocalizations l10n, {
    String? groupTitle,
  }) {
    return [
      MediaItem(
        id: AaMediaId.mix('most_played'),
        title: l10n.mostPlayed,
        artUri: AaContentStyles.drawableUri('cover_most_played'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
          groupTitle: groupTitle,
        ),
      ),
      MediaItem(
        id: AaMediaId.mix('recently_played'),
        title: l10n.recentlyPlayed,
        artUri: AaContentStyles.drawableUri('cover_recently_played'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
          groupTitle: groupTitle,
        ),
      ),
      MediaItem(
        id: AaMediaId.mix('forgotten_favorites'),
        title: l10n.forgottenFavorites,
        artUri: AaContentStyles.drawableUri('cover_forgotten_favorites'),
        playable: false,
        extras: AaContentStyles.styleExtras(
          browsable: AaContentStyles.styleGrid,
          playable: AaContentStyles.styleList,
          groupTitle: groupTitle,
        ),
      ),
    ];
  }

  MediaItem _pulseDropToItem(
    AskProactiveDrop drop,
    AppLocalizations l10n, {
    String? groupTitle,
  }) {
    return MediaItem(
      id: AaMediaId.action(AaMediaId.actPulseDrop, 'drop', drop.id),
      title: drop.title,
      displaySubtitle: drop.body,
      artUri: AaContentStyles.drawableUri('cover_pulse_drops'),
      playable: true,
      extras: AaContentStyles.styleExtras(
        playable: AaContentStyles.styleGrid,
        groupTitle: groupTitle,
      ),
    );
  }

  Uri? _mixArt(AskMixAttachment mix) {
    for (final t in mix.tracks) {
      if (t.thumbnailUrl != null && t.thumbnailUrl!.isNotEmpty) {
        return Uri.tryParse(t.thumbnailUrl!);
      }
    }
    return null;
  }

  Future<void> _addOfflineDownloadShortcuts(
    List<MediaItem> items,
    AppLocalizations l10n,
  ) async {
    final groups = await _downloadsBuilder.getGroups();
    for (final group in groups.take(4)) {
      if (group.kind == DownloadGroupKind.singles) {
        final tracks = AaDownloadsBuilder.sortGroupTracks(group);
        for (var i = 0; i < tracks.length && i < 4; i++) {
          items.add(
            AaContentMapper.downloadToMediaItem(
              tracks[i],
              index: i,
              groupKey: group.key,
              groupTitle: l10n.downloads,
            ),
          );
        }
      } else {
        final thumb = group.thumbnailUrl;
        items.add(
          MediaItem(
            id: AaMediaId.downloadGroup(group.key),
            title: group.name,
            displaySubtitle: l10n.songCount(group.tracks.length),
            artUri: thumb != null
                ? Uri.tryParse(thumb)
                : AaContentStyles.drawableUri('cover_downloads'),
            playable: false,
            extras: AaContentStyles.styleExtras(
              browsable: AaContentStyles.styleGrid,
              playable: AaContentStyles.styleList,
              groupTitle: l10n.downloads,
            ),
          ),
        );
      }
    }
  }

  Future<List<AaAskMixEntry>> getRecentAskMixes({int limit = 5}) async {
    if (_askStorageRepo == null) return const [];
    final convs = await _askStorageRepo.getConversations();
    final mixes = <AaAskMixEntry>[];
    for (final conv in convs.take(4)) {
      final msgs = await _askStorageRepo.getMessages(conv.id);
      for (final msg in msgs.reversed) {
        for (var i = 0; i < msg.attachments.length; i++) {
          final att = msg.attachments[i];
          if (att is AskMixAttachment && att.tracks.isNotEmpty) {
            mixes.add(
              AaAskMixEntry(messageId: msg.id, attachmentIndex: i, mix: att),
            );
            if (mixes.length >= limit) return mixes;
          }
        }
      }
    }
    return mixes;
  }

  Future<AskMixAttachment?> findAskMix(
    String messageId,
    int attachmentIndex,
  ) async {
    if (_askStorageRepo == null) return null;
    final convs = await _askStorageRepo.getConversations();
    for (final conv in convs.take(10)) {
      final msgs = await _askStorageRepo.getMessages(conv.id);
      for (final msg in msgs) {
        if (msg.id != messageId) continue;
        if (attachmentIndex >= 0 && attachmentIndex < msg.attachments.length) {
          final att = msg.attachments[attachmentIndex];
          if (att is AskMixAttachment) return att;
        }
      }
    }
    return null;
  }

  Future<List<MediaItem>> buildHomeSectionChildren(String parentMediaId) async {
    final index = int.tryParse(
      parentMediaId.substring(AaMediaId.homeSectionPrefix.length),
    );
    if (index == null) return const [];
    final home = await _cache.getHome();
    if (index < 0 || index >= home.sections.length) return const [];
    final section = home.sections[index];
    final items = <MediaItem>[];
    for (var i = 0; i < section.contents.length; i++) {
      items.addAll(
        AaContentMapper.homeContentToMediaItems(
          section.contents[i],
          contextKind: AaMediaId.ctxHomeSection,
          contextId: '$index',
          contextIndex: i,
        ),
      );
    }
    return items;
  }

  Future<List<MediaItem>> buildHomeChipChildren(String parentMediaId) async {
    final params = Uri.decodeComponent(
      parentMediaId.substring(AaMediaId.homeChipPrefix.length),
    );
    if (params.isEmpty) return const [];
    final result = await _cache.getHome(params: params);
    final items = <MediaItem>[];
    for (final section in result.sections) {
      if (section.contents.isEmpty) continue;
      for (final content in section.contents) {
        items.addAll(
          AaContentMapper.homeContentToMediaItems(
            content,
            groupTitle: section.title,
            browsableStyle: AaContentStyles.styleGrid,
          ),
        );
      }
    }
    return items;
  }

  /// Resolves songs/videos for a Home section at [sectionIndex].
  Future<List<dynamic>> resolveHomeSectionSongs(int sectionIndex) async {
    final home = await _cache.getHome();
    if (sectionIndex < 0 || sectionIndex >= home.sections.length) {
      return const [];
    }
    return home.sections[sectionIndex].contents
        .where(
          (c) =>
              (c is SongDetailed && c.isPlayable) ||
              (c is VideoDetailed && c.isPlayable) ||
              (c is EpisodeDetailed && c.videoId.isNotEmpty),
        )
        .toList(growable: false);
  }

  String artistSubtitle(List<ArtistBasic> artists) => displayArtists(artists);
}
