import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'media_cache_service.dart';

class _ByteInterval {
  int start;
  int end;
  _ByteInterval(this.start, this.end);
}

class _WrittenRanges {
  final List<_ByteInterval> _intervals = [];

  void addRange(int start, int end) {
    if (end <= start) return;
    _intervals.add(_ByteInterval(start, end));
    _intervals.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_ByteInterval>[];
    for (final cur in _intervals) {
      if (merged.isEmpty || cur.start > merged.last.end) {
        merged.add(cur);
      } else if (cur.end > merged.last.end) {
        merged.last.end = cur.end;
      }
    }
    _intervals
      ..clear()
      ..addAll(merged);
  }

  /// Contiguous available byte count starting at [offset], or `0` if absent.
  int availableFrom(int offset) {
    for (final iv in _intervals) {
      if (offset < iv.start) return 0;
      if (offset < iv.end) return iv.end - offset;
    }
    return 0;
  }

  bool isComplete(int totalBytes) {
    if (totalBytes <= 0 || _intervals.isEmpty) return false;
    return _intervals.first.start == 0 && _intervals.first.end >= totalBytes;
  }
}

/// Bridges a [SabrAudioStreamInfo] into HTTP `200`/`206` byte-range responses
/// backed by a sparse temporary file and time-based SABR seeking.
class SabrProxySession {
  static const int _seekJumpThresholdBytes = 512 * 1024;
  static const int _readChunkBytes = 64 * 1024;
  static const Duration _waitTimeout = Duration(seconds: 30);

  final String videoId;
  final SabrAudioStreamInfo sabrStream;
  final Stream<SabrChunk> Function({int initialPlayerTimeMs}) _openChunks;
  final MediaCacheService _mediaCacheService;
  final Directory? _tempDir;
  final void Function()? _onAttestationFailure;

  final _WrittenRanges _ranges = _WrittenRanges();
  final Map<int, int> _segmentRangeToMs = {};
  final StreamController<void> _updates = StreamController<void>.broadcast();

  File? _tempFile;
  RandomAccessFile? _raf;
  Future<void> _ioSerial = Future<void>.value();

  StreamSubscription<SabrChunk>? _activeSub;
  int _pumpGeneration = 0;
  int? _activePumpCursor;
  bool _pumpDone = false;
  Object? _pumpError;
  bool _promoted = false;
  bool _disposed = false;

  SabrProxySession({
    required this.videoId,
    required this.sabrStream,
    required this._openChunks,
    MediaCacheService? mediaCacheService,
    this._tempDir,
    this._onAttestationFailure,
  }) : _mediaCacheService = mediaCacheService ?? MediaCacheService.instance;

  bool get isDisposed => _disposed;

  Future<T> _withIo<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _ioSerial = _ioSerial.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<RandomAccessFile> _ensureFile() async {
    final existing = _raf;
    if (existing != null) return existing;
    final dir = _tempDir ?? await getTemporaryDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(
      '${dir.path}/sonora_sabr_${videoId}_${sabrStream.tag}_${identityHashCode(this)}.tmp',
    );
    _tempFile = file;
    final raf = await file.open(mode: FileMode.write);
    _raf = raf;
    return raf;
  }

  Future<void> _startPump(int initialPlayerTimeMs) async {
    await _activeSub?.cancel();
    _activeSub = null;
    if (_disposed) return;

    await _withIo(_ensureFile);
    if (_disposed) return;

    final gen = ++_pumpGeneration;
    _pumpDone = false;
    _pumpError = null;
    _activePumpCursor = null;

    late final StreamSubscription<SabrChunk> sub;
    sub = _openChunks(initialPlayerTimeMs: initialPlayerTimeMs).listen(
      (chunk) {
        if (_disposed || gen != _pumpGeneration) return;
        sub.pause();
        _withIo(() async {
          if (_disposed || gen != _pumpGeneration) return;
          final raf = await _ensureFile();
          await raf.setPosition(chunk.startRange);
          await raf.writeFrom(chunk.data);
          _ranges.addRange(chunk.startRange, chunk.endRangeExclusive);
          if (!chunk.isInitialization && chunk.startMs != null) {
            _segmentRangeToMs[chunk.startRange] = chunk.startMs!;
          }
          _activePumpCursor = chunk.endRangeExclusive;
        }).then(
          (_) {
            _notify();
            if (!_disposed && gen == _pumpGeneration) {
              sub.resume();
            }
          },
          onError: (Object e, StackTrace s) {
            if (gen == _pumpGeneration) {
              _pumpError = e;
              _pumpDone = true;
              _notify();
            }
          },
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed || gen != _pumpGeneration) return;
        dev.log('[SabrProxySession] SABR error for $videoId: $error');
        if (error is SabrProtocolException &&
            error.kind == SabrFailureKind.attestationRequired) {
          _onAttestationFailure?.call();
        }
        _pumpError = error;
        _pumpDone = true;
        _notify();
      },
      onDone: () {
        if (_disposed || gen != _pumpGeneration) return;
        _withIo(() async {
          if (_disposed || gen != _pumpGeneration) return;
          await _raf?.flush();
          final totalBytes = sabrStream.size.totalBytes;
          if (!_promoted &&
              _tempFile != null &&
              _ranges.isComplete(totalBytes)) {
            _promoted = true;
            unawaited(
              _mediaCacheService.promoteFileToCache(
                videoId: videoId,
                extension: sabrStream.container.name,
                sourceFile: _tempFile!,
              ),
            );
          }
        }).whenComplete(() {
          if (gen == _pumpGeneration) {
            _pumpDone = true;
            _notify();
          }
        });
      },
      cancelOnError: true,
    );
    _activeSub = sub;
  }

  void _notify() {
    if (!_updates.isClosed) {
      _updates.add(null);
    }
  }

  int _estimateTimeMsForOffset(int byteOffset, int totalBytes) {
    final durationMs = sabrStream.duration.inMilliseconds;
    if (durationMs <= 0 || totalBytes <= 0 || byteOffset <= 0) return 0;

    int? bestRange;
    int? bestMs;
    for (final entry in _segmentRangeToMs.entries) {
      if (entry.key <= byteOffset &&
          (bestRange == null || entry.key > bestRange)) {
        bestRange = entry.key;
        bestMs = entry.value;
      }
    }
    if (bestMs != null) return bestMs;

    final estimated = ((byteOffset * durationMs) / totalBytes).round();
    return estimated.clamp(0, math.max(0, durationMs - 1000));
  }

  /// Serves a full `200 OK` or partial `206 Partial Content` HTTP response for
  /// [rangeHeaderStr].
  Future<Response> serveRange(String? rangeHeaderStr) async {
    if (_disposed) {
      return Response(
        HttpStatus.serviceUnavailable,
        body: 'SABR session disposed',
      );
    }

    final totalBytes = sabrStream.size.totalBytes;
    final contentType = sabrStream.codec.mimeType;

    if (totalBytes <= 0) {
      return Response.ok(
        _openChunks(initialPlayerTimeMs: 0).map((c) => c.data),
        headers: {'Content-Type': contentType},
      );
    }

    final hasRange =
        rangeHeaderStr != null && rangeHeaderStr.startsWith('bytes=');
    var start = 0;
    var end = totalBytes - 1;
    if (hasRange) {
      final rangeValue = rangeHeaderStr.substring(6).trim();
      final parts = rangeValue.split('-');
      start = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]) ?? (totalBytes - 1);
      }
    }

    final safeEnd = math.min(end, totalBytes - 1);
    final safeStart = start > safeEnd ? 0 : math.max(0, start);
    final contentLength = safeEnd - safeStart + 1;

    final bodyStream = _streamRange(safeStart, safeEnd, totalBytes);

    if (hasRange) {
      return Response(
        HttpStatus.partialContent,
        body: bodyStream,
        headers: {
          'Content-Type': contentType,
          'Content-Length': contentLength.toString(),
          'Content-Range': 'bytes $safeStart-$safeEnd/$totalBytes',
          'Accept-Ranges': 'bytes',
        },
      );
    }

    return Response.ok(
      bodyStream,
      headers: {
        'Content-Type': contentType,
        'Content-Length': totalBytes.toString(),
        'Accept-Ranges': 'bytes',
      },
    );
  }

  Stream<List<int>> _streamRange(int start, int end, int totalBytes) async* {
    if (_ranges.availableFrom(start) == 0) {
      final activeCursor = _activePumpCursor;
      final needsRestart =
          _activeSub == null ||
          _pumpDone ||
          (activeCursor != null &&
              (start < activeCursor ||
                  start > activeCursor + _seekJumpThresholdBytes));
      if (needsRestart) {
        final targetMs = _estimateTimeMsForOffset(start, totalBytes);
        await _startPump(targetMs);
      }
    }

    var cursor = start;
    var correctiveRestartUsed = false;

    while (cursor <= end && !_disposed) {
      final available = _ranges.availableFrom(cursor);
      if (available > 0) {
        final toRead = math.min(
          math.min(available, end - cursor + 1),
          _readChunkBytes,
        );
        final chunk = await _withIo(() async {
          final raf = _raf;
          if (raf == null || _disposed) return <int>[];
          await raf.setPosition(cursor);
          return raf.read(toRead);
        });
        if (chunk.isEmpty) {
          throw StateError('SABR temp file read returned 0 bytes at $cursor');
        }
        yield chunk;
        cursor += chunk.length;
        continue;
      }

      if (_pumpError != null) {
        throw _pumpError!;
      }
      if (_pumpDone) {
        if (!correctiveRestartUsed) {
          correctiveRestartUsed = true;
          final fallbackMs = math.max(
            0,
            _estimateTimeMsForOffset(cursor, totalBytes) - 2000,
          );
          await _startPump(fallbackMs);
          continue;
        }
        throw StateError('SABR stream ended before byte $cursor');
      }

      await _updates.stream.first.timeout(_waitTimeout);
    }
  }

  /// Stops active SABR streams and deletes the backing temporary file.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _activeSub?.cancel();
    _activeSub = null;
    await _updates.close();
    await _withIo(() async {
      await _raf?.close();
      _raf = null;
      final file = _tempFile;
      _tempFile = null;
      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    });
  }
}
