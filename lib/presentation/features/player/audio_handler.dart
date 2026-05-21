import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:just_audio/just_audio.dart';

import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';

class SonoraAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final MusicRepository _musicRepo;
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;

  Duration _crossfadeDuration = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;
  int _retryCount = 0;
  bool _isRetrying = false;
  StreamSubscription<PlayerException>? _playerErrorSub;

  // ── Android Auto extras ──────────────────────────────────────────────────────
  static const String _kContentStyleBrowsable =
      'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
  static const String _kContentStylePlayable =
      'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT';
  static const int _kStyleList = 1;

  static const String _actionShuffle = 'shuffle';
  static const String _actionRepeat = 'repeat';
  static const String _actionLike = 'like';
  static const String _actionSleepTimer = 'sleep_timer';

  // ── AA content tree IDs ──────────────────────────────────────────────────────
  // audio_service returns BrowserRoot("/") to AA, so the root parentMediaId is "/"
  static const String _rootId = '/';
  // Top-level
  static const String _homeId = '__home__';
  static const String _libraryId = '__library__';
  // Library sub-nodes
  static const String _recentId = '__recent__';
  static const String _likedId = '__liked__';
  static const String _playlistsId = '__playlists__';
  static const String _artistsId = '__artists__';
  static const String _albumsId = '__albums__';
  static const String _historyId = '__history__';
  // Dynamic prefixes
  static const String _homeSectionPrefix = '__home_section__:';
  static const String _playlistPrefix = '__playlist__:';
  static const String _artistPrefix = '__artist__:';
  static const String _homeAlbumPrefix = '__home_album__:';
  static const String _homePlaylistPrefix = '__home_playlist__:';

  SonoraAudioHandler({
    required MusicRepository musicRepo,
    required LibraryRepository libraryRepo,
    required PlayVideoIdUseCase playVideoIdUseCase,
  }) : _musicRepo = musicRepo,
       _libraryRepo = libraryRepo,
       _playVideoIdUseCase = playVideoIdUseCase {
    _setupListeners();
    _playerErrorSub = _player.errorStream.listen(_onPlayerError);
  }

  Stream<Duration?> get durationStream => _player.durationStream;

  void _setupListeners() {
    _player.playerStateStream.listen(_onPlayerStateChanged);
    _player.positionStream.listen(_onPositionChanged);
    _player.bufferedPositionStream.listen(_onBufferedPositionChanged);
    _player.currentIndexStream.listen(_onCurrentIndexChanged);
    _player.sequenceStateStream.listen(_onSequenceStateChanged);
  }

  void _onPlayerStateChanged(PlayerState state) {
    final processing = switch (state.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    if (state.processingState == ProcessingState.ready) {
      _retryCount = 0;
    }

    final current = playbackState.value;

    playbackState.add(
      current.copyWith(
        processingState: processing,
        playing: state.playing,
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: 'drawable/ic_shuffle',
            label:
                current.shuffleMode == AudioServiceShuffleMode.all
                    ? 'Shuffle On'
                    : 'Shuffle',
            name: _actionShuffle,
          ),
          MediaControl.custom(
            androidIcon: 'drawable/ic_repeat',
            label: switch (current.repeatMode) {
              AudioServiceRepeatMode.one => 'Repeat One',
              AudioServiceRepeatMode.all => 'Repeat All',
              _ => 'Repeat',
            },
            name: _actionRepeat,
          ),
          MediaControl.custom(
            androidIcon: 'drawable/ic_favorite',
            label: 'Like',
            name: _actionLike,
          ),
          MediaControl.custom(
            androidIcon: 'drawable/ic_timer',
            label: 'Sleep Timer',
            name: _actionSleepTimer,
          ),
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRating,
        },
        androidCompactActionIndices: const [0, 1, 2],
      ),
    );
  }

  void _onPositionChanged(Duration position) {
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    _handleCrossfade(position);
  }

  void _onBufferedPositionChanged(Duration position) {
    playbackState.add(playbackState.value.copyWith(bufferedPosition: position));
  }

  void _onCurrentIndexChanged(int? index) {
    if (index == null) return;
    playbackState.add(playbackState.value.copyWith(queueIndex: index));
  }

  void _onSequenceStateChanged(SequenceState? sequenceState) {
    if (sequenceState == null) return;
    final source = sequenceState.currentSource;
    if (source != null) {
      mediaItem.add(source.tag as MediaItem);
    }
    final items =
        sequenceState.effectiveSequence.map((e) => e.tag as MediaItem).toList();
    queue.add(items);

    if (_crossfadeDuration > Duration.zero && _player.playing) {
      _isFadingIn = true;
      _applyVolume(0.0);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    if (duration == Duration.zero) _applyVolume(1.0);
  }

  void _applyVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _lastSetVolume).abs() > 0.005) {
      _lastSetVolume = v;
      _player.setVolume(v);
    }
  }

  void _handleCrossfade(Duration position) {
    if (_crossfadeDuration == Duration.zero) return;
    final duration = _player.duration;
    if (duration == null || !_player.playing) return;

    if (_isFadingIn) {
      final fadeMs = _crossfadeDuration.inMilliseconds;
      final vol = fadeMs > 0 ? position.inMilliseconds / fadeMs : 1.0;
      if (vol >= 1.0) {
        _applyVolume(1.0);
        _isFadingIn = false;
      } else {
        _applyVolume(vol);
      }
      return;
    }

    final remaining = duration - position;
    if (remaining > Duration.zero && remaining <= _crossfadeDuration) {
      _applyVolume(
        remaining.inMilliseconds / _crossfadeDuration.inMilliseconds,
      );
    } else if (remaining > _crossfadeDuration) {
      _applyVolume(1.0);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => LoopMode.all,
    };
    await _player.setLoopMode(loopMode);
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  List<MediaItem> get _currentQueue =>
      _player.sequence.map((e) => e.tag as MediaItem).toList();

  AudioSource _toAudioSource(MediaItem item) {
    final url = item.extras?['url'] as String?;
    if (url != null && url.isNotEmpty) {
      return AudioSource.uri(Uri.parse(url), tag: item);
    }
    return AudioSource.uri(
      Uri.parse(
        'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=',
      ),
      tag: item,
    );
  }

  Future<void> setQueue(List<MediaItem> items, {int initialIndex = 0}) async {
    queue.add(items);
    await _player.setAudioSources(
      items.map(_toAudioSource).toList(),
      initialIndex: initialIndex,
    );
  }

  Future<void> playNow(List<MediaItem> items, {int initialIndex = 0}) async {
    await setQueue(items, initialIndex: initialIndex);
    await _player.play();
  }

  Future<void> playNext(MediaItem item) async {
    final ci = _player.currentIndex ?? 0;
    final insertAt = (ci + 1).clamp(0, _player.sequence.length);
    await _player.insertAudioSource(insertAt, _toAudioSource(item));
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    await _player.addAudioSource(_toAudioSource(mediaItem));
  }

  Future<void> addToQueue(MediaItem item) async {
    await addQueueItem(item);
  }

  Future<void> addAllToQueue(List<MediaItem> items) async {
    await _player.addAudioSources(items.map(_toAudioSource).toList());
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _player.sequence.length) return;
    await _player.removeAudioSourceAt(index);
  }

  Future<void> clearQueue() async {
    await _player.stop();
    await _player.clearAudioSources();
    queue.add([]);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final len = _player.sequence.length;
    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;
    await _player.moveAudioSource(oldIndex, newIndex);
  }

  @override
  Future<void> onTaskRemoved() async {
    await _player.stop();
    await super.onTaskRemoved();
  }

  void _onPlayerError(PlayerException error) async {
    if (_isRetrying || _retryCount >= 1) return;
    final currentItem = mediaItem.value;
    final videoId = currentItem?.extras?['videoId'] as String?;
    if (videoId == null) return;

    _isRetrying = true;
    _retryCount++;
    try {
      dev.log('[AudioHandler] Stream URL expired for "$videoId", resolving fresh URL…');
      final freshUrl = await _playVideoIdUseCase.resolveUrl(videoId);
      final updatedItem = currentItem!.copyWith(
        extras: {...?currentItem.extras, 'url': freshUrl},
      );
      final currentIndex = _player.currentIndex ?? 0;
      await _player.removeAudioSourceAt(currentIndex);
      await _player.insertAudioSource(
        currentIndex,
        AudioSource.uri(Uri.parse(freshUrl), tag: updatedItem),
      );
      mediaItem.add(updatedItem);
      await _player.seek(Duration.zero, index: currentIndex);
      await _player.play();
      dev.log('[AudioHandler] Retry successful for "$videoId"');
    } catch (e) {
      dev.log('[AudioHandler] Retry failed for "$videoId": $e');
    }
    _isRetrying = false;
  }

  void dispose() {
    _playerErrorSub?.cancel();
    _player.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — getChildren (AA browse tree)
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    dev.log('[AA] getChildren: "$parentMediaId"');
    // audio_service may send '/', 'root', '' or 'root_id' for the root
    final isRoot =
        parentMediaId == _rootId ||
        parentMediaId == 'root' ||
        parentMediaId == 'root_id' ||
        parentMediaId.isEmpty;
    try {
      if (isRoot) return _buildRootChildren();

      switch (parentMediaId) {
        case _homeId:
          return _buildHomeChildren();

        case _libraryId:
          return _buildLibraryChildren();

        case _recentId:
          return _buildRecentChildren();

        case _likedId:
          return _buildLikedChildren();

        case _playlistsId:
          return _buildPlaylistFolders();

        case _artistsId:
          return _buildArtistFolders();

        case _albumsId:
          return _buildLikedAlbumFolders();

        case _historyId:
          return _buildRecentChildren();

        default:
          if (parentMediaId.startsWith(_homeSectionPrefix)) {
            return _buildHomeSectionChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_playlistPrefix)) {
            return _buildPlaylistEntryChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_artistPrefix)) {
            return _buildArtistSongChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homeAlbumPrefix)) {
            return _buildHomeAlbumSongChildren(parentMediaId);
          }
          if (parentMediaId.startsWith(_homePlaylistPrefix)) {
            return _buildHomePlaylistVideoChildren(parentMediaId);
          }
          return [];
      }
    } catch (e, st) {
      dev.log('[AA] getChildren error for "$parentMediaId": $e\n$st');
      return [];
    }
  }

  List<MediaItem> _buildRootChildren() {
    return [
      MediaItem(
        id: _homeId,
        title: 'Home',
        displaySubtitle: 'Homepage',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
      MediaItem(
        id: _libraryId,
        title: 'Library',
        displaySubtitle: 'Your music',
        playable: false,
        extras: {
          _kContentStyleBrowsable: _kStyleList,
          _kContentStylePlayable: _kStyleList,
        },
      ),
    ];
  }

  Future<List<MediaItem>> _buildLibraryChildren() async {
    final likedFuture = _libraryRepo.getAllLikedSongs();
    final artistsFuture = _libraryRepo.getAllFollowedArtists();
    final playlistsFuture = _libraryRepo.getAllPlaylists();
    final albumsFuture = _libraryRepo.getAllLikedAlbums();
    final historyFuture = _libraryRepo.getRecentHistory(limit: 50);
    final liked = await likedFuture;
    final artists = await artistsFuture;
    final playlists = await playlistsFuture;
    final albums = await albumsFuture;
    final history = await historyFuture;

    final items = <MediaItem>[];

    void addSection(String id, String title, List<MediaItem> sectionItems) {
      if (sectionItems.isEmpty) return;
      items.add(
        MediaItem(
          id: id,
          title: title,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      items.addAll(sectionItems.take(3));
    }

    addSection(
      _likedId,
      'Favorites',
      liked
          .map(
            (s) => MediaItem(
              id: s.videoId,
              title: s.title,
              artist: s.artist,
              artUri:
                  s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          )
          .toList(),
    );

    addSection(
      _artistsId,
      'Artists',
      artists
          .map(
            (a) => MediaItem(
              id: '$_artistPrefix${a.artistId}',
              title: a.name,
              artUri:
                  a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
              playable: false,
              extras: {_kContentStyleBrowsable: _kStyleList},
            ),
          )
          .toList(),
    );

    addSection(
      _playlistsId,
      'Playlists',
      playlists
          .map(
            (p) => MediaItem(
              id: '$_playlistPrefix${p.id}',
              title: p.name,
              playable: false,
              extras: {_kContentStyleBrowsable: _kStyleList},
            ),
          )
          .toList(),
    );

    addSection(
      _albumsId,
      'Albums',
      albums
          .map(
            (a) => MediaItem(
              id: '$_homeAlbumPrefix${a.albumId}',
              title: a.name,
              artist: a.artistName,
              artUri:
                  a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
              playable: false,
              extras: {_kContentStyleBrowsable: _kStyleList},
            ),
          )
          .toList(),
    );

    addSection(
      _historyId,
      'History',
      history
          .map(
            (h) => MediaItem(
              id: h.videoId,
              title: h.title,
              artist: h.artist,
              artUri:
                  h.thumbnailUrl != null ? Uri.tryParse(h.thumbnailUrl!) : null,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          )
          .toList(),
    );

    return items;
  }

  Future<List<MediaItem>> _buildHomeChildren() async {
    final sections = await _musicRepo.getHomeSections();
    dev.log('[AA] getHomeSections returned ${sections.length} sections');
    final items = <MediaItem>[];
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (section.contents.isEmpty) continue;
      final sectionItems =
          section.contents.expand(_contentToMediaItems).toList();
      if (sectionItems.isEmpty) continue;
      // Section header — browsable, clicking shows all items
      items.add(
        MediaItem(
          id: '$_homeSectionPrefix$i',
          title: section.title,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
      // First 5 items shown inline on this level
      items.addAll(sectionItems.take(3));
    }
    return items;
  }

  List<MediaItem> _contentToMediaItems(dynamic content) {
    if (content is SongDetailed) {
      return [
        MediaItem(
          id: content.videoId,
          title: content.name,
          artist: content.artist.name,
          album: content.album?.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: content.duration ?? 0),
          extras: {_kContentStylePlayable: _kStyleList},
        ),
      ];
    } else if (content is VideoDetailed) {
      return [
        MediaItem(
          id: content.videoId,
          title: content.name,
          artist: content.artist.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: content.duration ?? 0),
          extras: {_kContentStylePlayable: _kStyleList},
        ),
      ];
    } else if (content is AlbumDetailed) {
      return [
        MediaItem(
          id: '$_homeAlbumPrefix${content.albumId}',
          title: content.name,
          artist: content.artist.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    } else if (content is PlaylistDetailed) {
      return [
        MediaItem(
          id: '$_homePlaylistPrefix${content.playlistId}',
          title: content.name,
          artUri:
              content.thumbnails.isNotEmpty
                  ? Uri.tryParse(content.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      ];
    }
    return [];
  }

  Future<List<MediaItem>> _buildHomeSectionChildren(
    String parentMediaId,
  ) async {
    final index = int.tryParse(
      parentMediaId.substring(_homeSectionPrefix.length),
    );
    if (index == null) return [];
    final sections = await _musicRepo.getHomeSections();
    if (index >= sections.length) return [];
    final section = sections[index];
    return section.contents.expand(_contentToMediaItems).toList();
  }

  Future<List<MediaItem>> _buildRecentChildren() async {
    final history = await _libraryRepo.getRecentHistory(limit: 50);
    return history
        .map(
          (h) => MediaItem(
            id: h.videoId,
            title: h.title,
            artist: h.artist,
            artUri:
                h.thumbnailUrl != null ? Uri.tryParse(h.thumbnailUrl!) : null,
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildLikedChildren() async {
    final songs = await _libraryRepo.getAllLikedSongs();
    return songs
        .map(
          (s) => MediaItem(
            id: s.videoId,
            title: s.title,
            artist: s.artist,
            artUri:
                s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildPlaylistFolders() async {
    final playlists = await _libraryRepo.getAllPlaylists();
    return playlists
        .map(
          (p) => MediaItem(
            id: '$_playlistPrefix${p.id}',
            title: p.name,
            displaySubtitle: 'Playlist',
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildPlaylistEntryChildren(
    String parentMediaId,
  ) async {
    final playlistId = int.parse(
      parentMediaId.substring(_playlistPrefix.length),
    );
    final entries = await _libraryRepo.getPlaylistEntries(playlistId);

    final items = <MediaItem>[];
    for (final entry in entries) {
      final liked = await _libraryRepo.getLikedSong(entry.videoId);
      if (liked != null) {
        items.add(
          MediaItem(
            id: entry.videoId,
            title: liked.title,
            artist: liked.artist,
            artUri:
                liked.thumbnailUrl != null
                    ? Uri.tryParse(liked.thumbnailUrl!)
                    : null,
            duration: const Duration(seconds: 0),
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        );
      } else {
        items.add(
          MediaItem(
            id: entry.videoId,
            title: entry.videoId,
            artist: '',
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        );
      }
    }
    return items;
  }

  Future<List<MediaItem>> _buildArtistFolders() async {
    final artists = await _libraryRepo.getAllFollowedArtists();
    return artists
        .map(
          (a) => MediaItem(
            id: '$_artistPrefix${a.artistId}',
            title: a.name,
            displaySubtitle: 'Artist',
            artUri:
                a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildArtistSongChildren(String parentMediaId) async {
    final artistId = parentMediaId.substring(_artistPrefix.length);
    final songs = await _musicRepo.getArtistSongs(artistId);
    return songs
        .take(100)
        .map(
          (s) => MediaItem(
            id: s.videoId,
            title: s.name,
            artist: s.artist.name,
            artUri:
                s.thumbnails.isNotEmpty
                    ? Uri.tryParse(s.thumbnails.last.url)
                    : null,
            duration: Duration(seconds: s.duration ?? 0),
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildLikedAlbumFolders() async {
    final albums = await _libraryRepo.getAllLikedAlbums();
    return albums
        .map(
          (a) => MediaItem(
            id: '$_homeAlbumPrefix${a.albumId}',
            title: a.name,
            artist: a.artistName,
            artUri:
                a.thumbnailUrl != null ? Uri.tryParse(a.thumbnailUrl!) : null,
            playable: false,
            extras: {
              _kContentStyleBrowsable: _kStyleList,
              _kContentStylePlayable: _kStyleList,
            },
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildHomeAlbumSongChildren(
    String parentMediaId,
  ) async {
    final albumId = parentMediaId.substring(_homeAlbumPrefix.length);
    final album = await _musicRepo.getAlbum(albumId);
    return album.songs
        .take(100)
        .map(
          (s) => MediaItem(
            id: s.videoId,
            title: s.name,
            artist: s.artist.name,
            album: album.name,
            artUri:
                album.thumbnails.isNotEmpty
                    ? Uri.tryParse(album.thumbnails.last.url)
                    : null,
            duration: Duration(seconds: s.duration ?? 0),
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _buildHomePlaylistVideoChildren(
    String parentMediaId,
  ) async {
    final playlistId = parentMediaId.substring(_homePlaylistPrefix.length);
    final videos = await _musicRepo.getPlaylistVideos(playlistId);
    return videos
        .take(100)
        .map(
          (v) => MediaItem(
            id: v.videoId,
            title: v.name,
            artist: v.artist.name,
            artUri:
                v.thumbnails.isNotEmpty
                    ? Uri.tryParse(v.thumbnails.last.url)
                    : null,
            duration: Duration(seconds: v.duration ?? 0),
            extras: {_kContentStylePlayable: _kStyleList},
          ),
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromMediaId
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final item = await _playVideoIdUseCase.execute(mediaId);
      await playNow([item]);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — search (FAB / text search → list of results)
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final results = await _musicRepo.searchSongs(query);
      return results
          .map(
            (s) => MediaItem(
              id: s.videoId,
              title: s.name,
              artist: s.artist.name,
              artUri:
                  s.thumbnails.isNotEmpty
                      ? Uri.tryParse(s.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: s.duration ?? 0),
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — playFromSearch
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    try {
      final results = await _musicRepo.searchSongs(query);
      if (results.isEmpty) return;
      final item = await _playVideoIdUseCase.execute(results.first.videoId);
      await playNow([item]);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — setRating
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    if (!rating.hasHeart()) return;
    try {
      final current =
          _currentQueue
              .where((item) => item.id == mediaItem.value?.id)
              .firstOrNull;
      final videoId = current?.id ?? (mediaItem.value?.id ?? '');
      await _libraryRepo.toggleLikedSong(
        LikedSongModel(
          videoId: videoId,
          title: current?.title ?? 'Unknown',
          artist: current?.artist ?? 'Unknown Artist',
          thumbnailUrl: current?.artUri?.toString(),
          addedAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  Android Auto — customAction
  // ═══════════════════════════════════════════════════════════════

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case _actionShuffle:
        final current = playbackState.value.shuffleMode;
        final next =
            current == AudioServiceShuffleMode.none
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none;
        await setShuffleMode(next);

      case _actionRepeat:
        const modes = [
          AudioServiceRepeatMode.none,
          AudioServiceRepeatMode.all,
          AudioServiceRepeatMode.one,
        ];
        final current = playbackState.value.repeatMode;
        final idx = modes.indexOf(current);
        final next = modes[(idx + 1) % modes.length];
        await setRepeatMode(next);

      case _actionLike:
        final item = mediaItem.value;
        if (item == null) return null;
        await _libraryRepo.toggleLikedSong(
          LikedSongModel(
            videoId: item.id,
            title: item.title,
            artist: item.artist ?? 'Unknown Artist',
            thumbnailUrl: item.artUri?.toString(),
            addedAt: DateTime.now(),
          ),
        );

      case _actionSleepTimer:
        break;
    }
    return null;
  }
}
