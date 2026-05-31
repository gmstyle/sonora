import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:just_audio/just_audio.dart';

import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';
import '../../../domain/repositories/music_repository.dart';
import '../../../domain/usecases/player/play_album_use_case.dart';
import '../../../domain/usecases/player/play_playlist_use_case.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';

class SonoraAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final MusicRepository _musicRepo;
  final LibraryRepository _libraryRepo;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  late final PlayAlbumUseCase _playAlbumUseCase;
  late final PlayPlaylistUseCase _playPlaylistUseCase;

  Duration _crossfadeDuration = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;
  int _retryCount = 0;
  bool _isRetrying = false;
  bool _isCurrentSongLiked = false;
  String? _currentVideoId;
  StreamSubscription<PlayerException>? _playerErrorSub;
  final Set<String> _pendingResolutions = {};
  bool _isResolving = false;
  List<MediaItem>? _pendingQueueEmission;
  final StreamController<(String videoId, String title)>
  _onPlayErrorController =
      StreamController<(String videoId, String title)>.broadcast();

  Stream<(String videoId, String title)> get onPlayError =>
      _onPlayErrorController.stream;

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

  // ── AA browse-tree action IDs ──────────────────────────────────────────────
  static const String _actionPlayAlbum = '__action__:play_album:';
  static const String _actionShuffleAlbum = '__action__:shuffle_album:';
  static const String _actionLikeAlbum = '__action__:like_album:';
  static const String _actionPlayArtist = '__action__:play_artist:';
  static const String _actionShuffleArtist = '__action__:shuffle_artist:';
  static const String _actionFollowArtist = '__action__:follow_artist:';
  static const String _actionPlayPlaylist = '__action__:play_playlist:';
  static const String _actionShufflePlaylist = '__action__:shuffle_playlist:';
  static const String _actionLikePlaylist = '__action__:like_playlist:';

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
    _playAlbumUseCase = PlayAlbumUseCase(musicRepo);
    _playPlaylistUseCase = PlayPlaylistUseCase(musicRepo);
    _setupListeners();
    _playerErrorSub = _player.errorStream.listen(_onPlayerError);
  }

  Stream<Duration?> get durationStream => _player.durationStream;

  void _setupListeners() {
    _player.playerStateStream.listen(_onPlayerStateChanged);
    _player.positionStream.listen(_handleCrossfade);
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
        controls: _buildControls(current),
        updatePosition: _player.position,
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

  List<MediaControl> _buildControls(PlaybackState current) {
    return [
      MediaControl.skipToPrevious,
      if (current.playing) MediaControl.pause else MediaControl.play,
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
        androidIcon:
            _isCurrentSongLiked
                ? 'drawable/ic_favorite'
                : 'drawable/ic_favorite_border',
        label: _isCurrentSongLiked ? 'Unlike' : 'Like',
        name: _actionLike,
      ),
      MediaControl.custom(
        androidIcon: 'drawable/ic_timer',
        label: 'Sleep Timer',
        name: _actionSleepTimer,
      ),
    ];
  }

  void _rebuildControls() {
    final current = playbackState.value;
    playbackState.add(current.copyWith(controls: _buildControls(current)));
  }

  Future<void> _checkCurrentSongLiked(String videoId) async {
    _currentVideoId = videoId;
    try {
      final liked = await _libraryRepo.getLikedSong(videoId);
      if (_currentVideoId == videoId) {
        _isCurrentSongLiked = liked != null;
        _rebuildControls();
      }
    } catch (_) {
      // Silently fall back to unliked state.
    }
  }

  void _onBufferedPositionChanged(Duration position) {
    playbackState.add(playbackState.value.copyWith(bufferedPosition: position));
  }

  void _onCurrentIndexChanged(int? index) {
    if (index == null) return;
    playbackState.add(playbackState.value.copyWith(queueIndex: index));
    _resolvePendingItems(index);
  }

  /// Pre-resolves stream URLs for pending items ([needsUrl]) before they
  /// become current: resolves the item at [currentIndex] if needed (user
  /// skipped to a pending track), and proactively resolves the next 2 items
  /// so playback can transition seamlessly.
  Future<void> _resolvePendingItems(int currentIndex) async {
    if (_isResolving) return;
    _isResolving = true;
    try {
      await _resolveSinglePendingItem(currentIndex);
      await _resolveSinglePendingItem(currentIndex + 1);
      await _resolveSinglePendingItem(currentIndex + 2);
    } finally {
      _isResolving = false;
      if (_pendingQueueEmission != null) {
        queue.add(_pendingQueueEmission!);
        _pendingQueueEmission = null;
      }
    }
  }

  Future<void> _resolveSinglePendingItem(int index) async {
    if (index < 0) return;
    final seq = _player.sequenceState.effectiveSequence;
    if (index >= seq.length) return;
    final item = seq[index].tag as MediaItem;
    if (item.extras?['needsUrl'] != true) return;

    final videoId = item.extras?['videoId'] as String?;
    if (videoId == null || !_pendingResolutions.add(videoId)) return;

    try {
      final url = await _playVideoIdUseCase.resolveUrl(videoId);

      final seq2 = _player.sequenceState.effectiveSequence;
      if (index >= seq2.length) return;
      final currentItem = seq2[index].tag as MediaItem;
      if (currentItem.extras?['videoId'] != videoId) return;
      if (currentItem.extras?['needsUrl'] != true) return;

      final updatedItem = item.copyWith(
        extras: {...?item.extras, 'url': url, 'needsUrl': false},
      );

      await _player.removeAudioSourceAt(index);
      await _player.insertAudioSource(
        index,
        AudioSource.uri(Uri.parse(url), tag: updatedItem),
      );

      if (index == _player.currentIndex) {
        await _player.seek(Duration.zero, index: index);
        await _player.play();
      }
    } catch (_) {
    } finally {
      _pendingResolutions.remove(videoId);
    }
  }

  void _onSequenceStateChanged(SequenceState? sequenceState) {
    if (sequenceState == null) return;
    final source = sequenceState.currentSource;
    if (source != null) {
      final item = source.tag as MediaItem;
      mediaItem.add(item);
      _checkCurrentSongLiked(item.id);
    }
    final items =
        sequenceState.effectiveSequence.map((e) => e.tag as MediaItem).toList();

    if (_isResolving) {
      _pendingQueueEmission = items;
    } else {
      queue.add(items);
    }

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
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

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
      dev.log(
        '[AudioHandler] Stream URL expired for "$videoId", resolving fresh URL…',
      );
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
      _onPlayErrorController.add((videoId, currentItem?.title ?? videoId));
      if (_player.sequence.length > (_player.currentIndex ?? 0) + 1) {
        await _player.seekToNext();
      } else {
        await _player.stop();
      }
    }
    _isRetrying = false;
  }

  void dispose() {
    _playerErrorSub?.cancel();
    _onPlayErrorController.close();
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
            return _buildArtistChildren(parentMediaId);
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
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
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
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
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
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
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
          extras: {
            'needsUrl': true,
            'videoId': content.videoId,
            'isVideo': false,
            _kContentStylePlayable: _kStyleList,
          },
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
          extras: {
            'needsUrl': true,
            'videoId': content.videoId,
            'isVideo': true,
            _kContentStylePlayable: _kStyleList,
          },
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
            extras: {
              'needsUrl': true,
              'videoId': h.videoId,
              'isVideo': false,
              _kContentStylePlayable: _kStyleList,
            },
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
            extras: {
              'needsUrl': true,
              'videoId': s.videoId,
              'isVideo': false,
              _kContentStylePlayable: _kStyleList,
            },
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
    final playlistIdStr = playlistId.toString();

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayPlaylist$playlistIdStr',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShufflePlaylist$playlistIdStr',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    for (final entry in entries) {
      final liked = await _libraryRepo.getLikedSong(entry.videoId);
      final title = liked?.title ?? entry.title ?? entry.videoId;
      final artist = liked?.artist ?? entry.artist ?? '';
      final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
      items.add(
        MediaItem(
          id: entry.videoId,
          title: title,
          artist: artist,
          artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl) : null,
          duration: const Duration(seconds: 0),
          extras: {
            'needsUrl': true,
            'videoId': entry.videoId,
            'isVideo': false,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
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

  Future<List<MediaItem>> _buildArtistChildren(String parentMediaId) async {
    final artistId = parentMediaId.substring(_artistPrefix.length);
    final artistInfo = await _musicRepo.getArtist(artistId);
    final followed = await _libraryRepo.getFollowedArtist(artistId);

    final mediaItems = <MediaItem>[
      MediaItem(
        id: '$_actionPlayArtist$artistId',
        title: 'Play Top Songs',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleArtist$artistId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionFollowArtist$artistId',
        title: followed != null ? 'Following' : 'Follow',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    // 1. Top Songs (Playable)
    for (final song in artistInfo.topSongs) {
      mediaItems.add(
        MediaItem(
          id: song.videoId,
          title: song.name,
          artist: song.artist.name,
          artUri:
              song.thumbnails.isNotEmpty
                  ? Uri.tryParse(song.thumbnails.last.url)
                  : null,
          duration: Duration(seconds: song.duration ?? 0),
          playable: true,
          extras: {_kContentStylePlayable: _kStyleList},
        ),
      );
    }

    // 2. Albums (Browsable folders)
    for (final album in artistInfo.topAlbums) {
      mediaItems.add(
        MediaItem(
          id: '$_homeAlbumPrefix${album.albumId}',
          title: album.name,
          artist: 'Album',
          artUri:
              album.thumbnails.isNotEmpty
                  ? Uri.tryParse(album.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 3. Singles (Browsable folders)
    for (final single in artistInfo.topSingles) {
      mediaItems.add(
        MediaItem(
          id: '$_homeAlbumPrefix${single.albumId}',
          title: single.name,
          artist: 'Single',
          artUri:
              single.thumbnails.isNotEmpty
                  ? Uri.tryParse(single.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 4. Featured On (Playlists - Browsable folders)
    for (final playlist in artistInfo.featuredOn) {
      mediaItems.add(
        MediaItem(
          id: '$_homePlaylistPrefix${playlist.playlistId}',
          title: playlist.name,
          artist: 'Playlist',
          artUri:
              playlist.thumbnails.isNotEmpty
                  ? Uri.tryParse(playlist.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    // 5. Similar Artists (Browsable folders)
    for (final related in artistInfo.similarArtists) {
      mediaItems.add(
        MediaItem(
          id: '$_artistPrefix${related.artistId}',
          title: related.name,
          artist: 'Artist',
          artUri:
              related.thumbnails.isNotEmpty
                  ? Uri.tryParse(related.thumbnails.last.url)
                  : null,
          playable: false,
          extras: {
            _kContentStyleBrowsable: _kStyleList,
            _kContentStylePlayable: _kStyleList,
          },
        ),
      );
    }

    return mediaItems;
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
    final liked = await _libraryRepo.getLikedAlbum(albumId);

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayAlbum$albumId',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShuffleAlbum$albumId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionLikeAlbum$albumId',
        title: liked != null ? 'Unlike Album' : 'Like Album',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    items.addAll(
      album.songs
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
              extras: {
                'needsUrl': true,
                'videoId': s.videoId,
                'isVideo': false,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          ),
    );
    return items;
  }

  Future<List<MediaItem>> _buildHomePlaylistVideoChildren(
    String parentMediaId,
  ) async {
    final playlistId = parentMediaId.substring(_homePlaylistPrefix.length);
    final videos = await _musicRepo.getPlaylistVideos(playlistId);
    final liked = await _libraryRepo.getLikedPlaylist(playlistId);

    final items = <MediaItem>[
      MediaItem(
        id: '$_actionPlayPlaylist$playlistId',
        title: 'Play All',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionShufflePlaylist$playlistId',
        title: 'Shuffle',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
      MediaItem(
        id: '$_actionLikePlaylist$playlistId',
        title: liked != null ? 'Unlike Playlist' : 'Like Playlist',
        playable: true,
        extras: {_kContentStylePlayable: _kStyleList},
      ),
    ];

    items.addAll(
      videos
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
              extras: {
                'needsUrl': true,
                'videoId': v.videoId,
                'isVideo': true,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          ),
    );
    return items;
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
      // ── Album actions ────────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayAlbum)) {
        final albumId = mediaId.substring(_actionPlayAlbum.length);
        final album = await _musicRepo.getAlbum(albumId);
        final items = await _playAlbumUseCase.execute(album.songs);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleAlbum)) {
        final albumId = mediaId.substring(_actionShuffleAlbum.length);
        final album = await _musicRepo.getAlbum(albumId);
        final shuffled = List<SongDetailed>.from(album.songs)..shuffle();
        final items = await _playAlbumUseCase.execute(shuffled);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionLikeAlbum)) {
        final albumId = mediaId.substring(_actionLikeAlbum.length);
        final existing = await _libraryRepo.getLikedAlbum(albumId);
        if (existing != null) {
          await _libraryRepo.deleteLikedAlbum(albumId);
        } else {
          final album = await _musicRepo.getAlbum(albumId);
          await _libraryRepo.toggleLikedAlbum(
            LikedAlbumModel(
              albumId: albumId,
              name: album.name,
              artistName: album.artist.name,
              thumbnailUrl:
                  album.thumbnails.isNotEmpty
                      ? album.thumbnails.last.url
                      : null,
              year: album.year,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_homeAlbumPrefix$albumId',
          ),
        );
        return;
      }

      // ── Artist actions ───────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayArtist)) {
        final artistId = mediaId.substring(_actionPlayArtist.length);
        final artist = await _musicRepo.getArtist(artistId);
        final items = await _playAlbumUseCase.execute(artist.topSongs);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionShuffleArtist)) {
        final artistId = mediaId.substring(_actionShuffleArtist.length);
        final artist = await _musicRepo.getArtist(artistId);
        final shuffled = List<SongDetailed>.from(artist.topSongs)..shuffle();
        final items = await _playAlbumUseCase.execute(shuffled);
        await playNow(items);
        return;
      }
      if (mediaId.startsWith(_actionFollowArtist)) {
        final artistId = mediaId.substring(_actionFollowArtist.length);
        final existing = await _libraryRepo.getFollowedArtist(artistId);
        if (existing != null) {
          await _libraryRepo.deleteFollowedArtist(artistId);
        } else {
          final artist = await _musicRepo.getArtist(artistId);
          await _libraryRepo.toggleFollowedArtist(
            FollowedArtistModel(
              artistId: artistId,
              name: artist.name,
              thumbnailUrl:
                  artist.thumbnails.isNotEmpty
                      ? artist.thumbnails.last.url
                      : null,
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_artistPrefix$artistId',
          ),
        );
        return;
      }

      // ── Playlist actions ─────────────────────────────────────────
      if (mediaId.startsWith(_actionPlayPlaylist)) {
        final playlistId = mediaId.substring(_actionPlayPlaylist.length);
        final localId = int.tryParse(playlistId);
        if (localId != null) {
          // Local playlist — read entries from DB
          final entries = await _libraryRepo.getPlaylistEntries(localId);
          final items = <MediaItem>[];
          for (final entry in entries) {
            final liked = await _libraryRepo.getLikedSong(entry.videoId);
            final title = liked?.title ?? entry.title ?? entry.videoId;
            final artist = liked?.artist ?? entry.artist ?? '';
            final thumbUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
            items.add(
              MediaItem(
                id: entry.videoId,
                title: title,
                artist: artist,
                artUri: thumbUrl != null ? Uri.tryParse(thumbUrl) : null,
                extras: {
                  'needsUrl': true,
                  'videoId': entry.videoId,
                  'isVideo': false,
                  _kContentStylePlayable: _kStyleList,
                },
              ),
            );
          }
          if (items.isNotEmpty) {
            try {
              final url = await _playVideoIdUseCase.resolveUrl(items.first.id);
              items[0] = items.first.copyWith(
                extras: {...items.first.extras!, 'url': url, 'needsUrl': false},
              );
            } catch (_) {}
          }
          await playNow(items);
        } else {
          // YT Music playlist — fetch videos from API
          final videos = await _musicRepo.getPlaylistVideos(playlistId);
          final items = await _playPlaylistUseCase.execute(videos);
          await playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionShufflePlaylist)) {
        final playlistId = mediaId.substring(_actionShufflePlaylist.length);
        final localId = int.tryParse(playlistId);
        if (localId != null) {
          // Local playlist — read entries from DB
          final entries = await _libraryRepo.getPlaylistEntries(localId);
          var items = <MediaItem>[];
          for (final entry in entries) {
            final liked = await _libraryRepo.getLikedSong(entry.videoId);
            final title = liked?.title ?? entry.title ?? entry.videoId;
            final artist = liked?.artist ?? entry.artist ?? '';
            final thumbUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
            items.add(
              MediaItem(
                id: entry.videoId,
                title: title,
                artist: artist,
                artUri: thumbUrl != null ? Uri.tryParse(thumbUrl) : null,
                extras: {
                  'needsUrl': true,
                  'videoId': entry.videoId,
                  'isVideo': false,
                  _kContentStylePlayable: _kStyleList,
                },
              ),
            );
          }
          if (items.isNotEmpty) {
            items = List<MediaItem>.from(items)..shuffle();
            try {
              final url = await _playVideoIdUseCase.resolveUrl(items.first.id);
              items[0] = items.first.copyWith(
                extras: {...items.first.extras!, 'url': url, 'needsUrl': false},
              );
            } catch (_) {}
          }
          await playNow(items);
        } else {
          // YT Music playlist — fetch videos from API
          final videos = await _musicRepo.getPlaylistVideos(playlistId);
          final shuffled = List<VideoDetailed>.from(videos)..shuffle();
          final items = await _playPlaylistUseCase.execute(shuffled);
          await playNow(items);
        }
        return;
      }
      if (mediaId.startsWith(_actionLikePlaylist)) {
        final playlistId = mediaId.substring(_actionLikePlaylist.length);
        final existing = await _libraryRepo.getLikedPlaylist(playlistId);
        if (existing != null) {
          await _libraryRepo.deleteLikedPlaylist(playlistId);
        } else {
          // Fetch playlist metadata — getPlaylist for YT Music playlists
          final playlist = await _musicRepo.getPlaylist(playlistId);
          await _libraryRepo.toggleLikedPlaylist(
            LikedPlaylistModel(
              playlistId: playlistId,
              name: playlist.name,
              thumbnailUrl:
                  playlist.thumbnails.isNotEmpty
                      ? playlist.thumbnails.last.url
                      : null,
              videoCount: playlist.videoCount,
              addedAt: DateTime.now(),
            ),
          );
        }
        AudioServicePlatform.instance.notifyChildrenChanged(
          NotifyChildrenChangedRequest(
            parentMediaId: '$_homePlaylistPrefix$playlistId',
          ),
        );
        return;
      }

      // ── Default: single song play ───────────────────────────
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
      // Esegue le ricerche filtrate in parallelo per ottenere risultati ricchi e completi
      // invece della ricerca mista (che restituisce pochi elementi condensati).
      final futureArtists = _musicRepo.searchArtists(query);
      final futureSongs = _musicRepo.searchSongs(query);
      final futureAlbums = _musicRepo.searchAlbums(query);
      final futurePlaylists = _musicRepo.searchPlaylists(query);

      final results = await Future.wait([
        futureArtists,
        futureSongs,
        futureAlbums,
        futurePlaylists,
      ]);

      final artistsData = results[0];
      final songsData = results[1];
      final albumsData = results[2];
      final playlistsData = results[3];

      final artists = <MediaItem>[];
      final songs = <MediaItem>[];
      final albums = <MediaItem>[];
      final playlists = <MediaItem>[];

      // Mappatura Artisti
      for (final result in artistsData) {
        if (result is ArtistDetailed) {
          artists.add(
            MediaItem(
              id: '$_artistPrefix${result.artistId}',
              title: result.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Canzoni (e Video se presenti)
      for (final result in songsData) {
        if (result is SongDetailed) {
          songs.add(
            MediaItem(
              id: result.videoId,
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: result.duration ?? 0),
              playable: true,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          );
        } else if (result is VideoDetailed) {
          songs.add(
            MediaItem(
              id: result.videoId,
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              duration: Duration(seconds: result.duration ?? 0),
              playable: true,
              extras: {_kContentStylePlayable: _kStyleList},
            ),
          );
        }
      }

      // Mappatura Album
      for (final result in albumsData) {
        if (result is AlbumDetailed) {
          albums.add(
            MediaItem(
              id: '$_homeAlbumPrefix${result.albumId}',
              title: result.name,
              artist: result.artist.name,
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Mappatura Playlist
      for (final result in playlistsData) {
        if (result is PlaylistDetailed) {
          playlists.add(
            MediaItem(
              id: '$_homePlaylistPrefix${result.playlistId}',
              title: result.name,
              // Le API delle playlist specifiche non sempre espongono author.name facilmente
              // ma possiamo ometterlo e mostrare la thumbnail/titolo in Android Auto
              artUri:
                  result.thumbnails.isNotEmpty
                      ? Uri.tryParse(result.thumbnails.last.url)
                      : null,
              playable: false,
              extras: {
                _kContentStyleBrowsable: _kStyleList,
                _kContentStylePlayable: _kStyleList,
              },
            ),
          );
        }
      }

      // Ritorna la lista unita con priorità logica: Artisti > Canzoni > Album > Playlist
      return [...artists, ...songs, ...albums, ...playlists];
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
    _isCurrentSongLiked = !_isCurrentSongLiked;
    _rebuildControls();
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
        _isCurrentSongLiked = !_isCurrentSongLiked;
        _rebuildControls();
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
