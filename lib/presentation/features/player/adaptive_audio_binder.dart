import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import '../../../data/datasources/remote/stream_datasource.dart';
import '../../../domain/models/media_quality.dart';
import '../../../domain/models/queue_track.dart';

/// Attaches / clears an external audio track for adaptive HD video playback.
///
/// When the current [Media] was built as an adaptive candidate (`videoOnly`
/// proxy URI + `audioProxyUrl` extras), resolves whether the manifest actually
/// supports an adaptive pair and calls [Player.setAudioTrack] accordingly.
class AdaptiveAudioBinder {
  final Player _player;
  final StreamDatasource _streamDatasource;
  final MediaQuality Function() _getStreamAudioQuality;
  final MediaQuality Function() _getStreamVideoQuality;

  int _bindGeneration = 0;
  String? _boundKey;

  AdaptiveAudioBinder({
    required Player player,
    required StreamDatasource streamDatasource,
    required MediaQuality Function() getStreamAudioQuality,
    required MediaQuality Function() getStreamVideoQuality,
  }) : _player = player,
       _streamDatasource = streamDatasource,
       _getStreamAudioQuality = getStreamAudioQuality,
       _getStreamVideoQuality = getStreamVideoQuality;

  /// Rebinds external audio for the media currently at [playlist] index.
  Future<void> onPlaylistChanged(Playlist playlist) async {
    final index = playlist.index;
    if (index < 0 || index >= playlist.medias.length) {
      await _clearExternalAudio();
      return;
    }

    final media = playlist.medias[index];
    final extras = media.extras;
    final item = extras?['mediaItem'] as MediaItem?;
    final videoId =
        item != null ? QueueTrack.fromMediaItem(item).videoId : null;

    final isCandidate = extras?['adaptiveCandidate'] == true;
    final audioProxyUrl = extras?['audioProxyUrl'] as String?;

    if (!isCandidate || audioProxyUrl == null || audioProxyUrl.isEmpty) {
      await _clearExternalAudio();
      return;
    }

    if (videoId == null || videoId.isEmpty) {
      await _clearExternalAudio();
      return;
    }

    final bindKey = '$videoId|$audioProxyUrl';
    if (_boundKey == bindKey) return;

    final generation = ++_bindGeneration;
    try {
      final plan = await _streamDatasource.ensurePlaybackSelection(
        videoId,
        audioQuality: _getStreamAudioQuality(),
        videoQuality: _getStreamVideoQuality(),
        preferVideo: true,
      );

      // Skip if a newer bind started (rapid skip).
      if (generation != _bindGeneration) return;

      if (!plan.isAdaptive) {
        await _clearExternalAudio();
        return;
      }

      await _player.setAudioTrack(
        AudioTrack.uri(audioProxyUrl, title: 'sonora-yt-audio'),
      );
      if (generation == _bindGeneration) {
        _boundKey = bindKey;
      }
      dev.log('[AdaptiveAudioBinder] Bound external audio for $videoId');
    } catch (e) {
      dev.log('[AdaptiveAudioBinder] Failed to bind audio for $videoId: $e');
      if (generation == _bindGeneration) {
        try {
          await _clearExternalAudio();
        } catch (_) {}
      }
    }
  }

  Future<void> _clearExternalAudio() async {
    _boundKey = null;
    try {
      await _player.setAudioTrack(AudioTrack.auto());
    } catch (e) {
      dev.log('[AdaptiveAudioBinder] clear external audio failed: $e');
    }
  }
}
