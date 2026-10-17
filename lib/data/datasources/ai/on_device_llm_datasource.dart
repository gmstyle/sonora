import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../../../core/constants/ai_constants.dart';

/// Thin wrapper around Flutter Edge AI / LiteRT-LM for the Ask model.
///
/// Keeps a long-lived [InferenceModel] — reloading weights on every call was
/// hanging on Linux at "Loading native libraries…".
class OnDeviceLlmDatasource {
  bool _initialized = false;
  InferenceModel? _model;
  Future<InferenceModel>? _modelFuture;

  /// Serialize inference — LiteRT-LM is not safe for concurrent sessions.
  Future<void> _tail = Future<void>.value();

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    _initialized = true;
  }

  Future<bool> isModelReady() async {
    await ensureInitialized();
    return FlutterEdgeAi.isModelInstalled(kAskLlmFilename);
  }

  Future<void> installModel({
    void Function(double progress)? onProgress,
  }) async {
    await ensureInitialized();
    await _disposeCachedModel();
    await _uninstallLegacyQuietly();
    var builder = FlutterEdgeAi.installModel(
      modelType: ModelType.qwen3,
      fileType: ModelFileType.litertlm,
    ).fromHuggingFace(kAskLlmHfRepo, file: kAskLlmFilename);
    if (onProgress != null) {
      builder = builder.withProgress((p) {
        // Plugin reports 0–100.
        onProgress((p.clamp(0, 100)) / 100.0);
      });
    }
    await builder.install();
  }

  Future<void> uninstallModel() async {
    await ensureInitialized();
    await _disposeCachedModel();
    try {
      await FlutterEdgeAi.uninstallModel(kAskLlmFilename);
    } catch (e, st) {
      debugPrint('Ask model uninstall failed: $e\n$st');
    }
    await _uninstallLegacyQuietly();
    await FlutterEdgeAi.clearActiveInferenceIdentity();
  }

  Future<void> _uninstallLegacyQuietly() async {
    try {
      if (await FlutterEdgeAi.isModelInstalled(kAskLlmLegacyFilename)) {
        await FlutterEdgeAi.uninstallModel(kAskLlmLegacyFilename);
      }
    } catch (e, st) {
      debugPrint('Ask legacy model uninstall failed: $e\n$st');
    }
  }

  /// Eagerly load weights so the first Ask call is not a cold start.
  Future<void> warmUp() async {
    await ensureInitialized();
    if (!await isModelReady()) return;
    await _ensureModel();
  }

  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) {
    final done = Completer<String>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        final text = await _completeUnlocked(
          systemInstruction: systemInstruction,
          userMessage: userMessage,
          maxOutputTokens: maxOutputTokens,
        );
        done.complete(text);
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<String> _completeUnlocked({
    required String systemInstruction,
    required String userMessage,
    required int maxOutputTokens,
  }) async {
    await ensureInitialized();
    if (!await isModelReady()) {
      throw StateError('Ask model is not installed');
    }

    final model = await _ensureModel();
    debugPrint('OnDeviceLlm: createSession…');
    final session = await model.createSession(
      systemInstruction: systemInstruction,
      enableThinking: false,
      maxOutputTokens: maxOutputTokens,
      temperature: 0.2,
      topK: 40,
      topP: 0.9,
    );
    try {
      await session.addQueryChunk(Message(text: userMessage, isUser: true));
      debugPrint('OnDeviceLlm: getResponse…');
      final response = await session.getResponse().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw TimeoutException('Ask model getResponse timed out after 90s');
        },
      );
      debugPrint('OnDeviceLlm: getResponse done (${response.length} chars)');
      return response;
    } finally {
      await session.close();
      // Keep [_model] alive — closing it forces a full native reload next time.
    }
  }

  Future<InferenceModel> _ensureModel() {
    if (_model != null) return Future.value(_model);
    final existing = _modelFuture;
    if (existing != null) return existing;

    final future = _loadModel();
    _modelFuture = future;
    return future;
  }

  Future<InferenceModel> _loadModel() async {
    // Re-bind active identity if the process restarted with files still on disk.
    if (!FlutterEdgeAi.hasActiveModel()) {
      debugPrint('OnDeviceLlm: rebinding active model identity');
      await installModel();
    }

    debugPrint('OnDeviceLlm: getActiveModel (cold load)…');
    try {
      final model = await FlutterEdgeAi.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException(
            'Ask model getActiveModel timed out after 120s',
          );
        },
      );
      _model = model;
      _modelFuture = null;
      debugPrint('OnDeviceLlm: getActiveModel ready');
      return model;
    } catch (_) {
      _modelFuture = null;
      rethrow;
    }
  }

  Future<void> _disposeCachedModel() async {
    final model = _model;
    _model = null;
    _modelFuture = null;
    if (model == null) return;
    try {
      await model.close();
    } catch (e, st) {
      debugPrint('OnDeviceLlm: model.close failed: $e\n$st');
    }
  }
}
