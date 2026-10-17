import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../../../core/constants/ai_constants.dart';

/// Thin wrapper around Flutter Edge AI / LiteRT-LM for the Ask model.
class OnDeviceLlmDatasource {
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
    );
    _initialized = true;
  }

  Future<bool> isModelReady() async {
    await ensureInitialized();
    return FlutterEdgeAi.isModelInstalled(kAskLlmFilename);
  }

  Future<void> installModel({void Function(double progress)? onProgress}) async {
    await ensureInitialized();
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
    try {
      await FlutterEdgeAi.uninstallModel(kAskLlmFilename);
    } catch (e, st) {
      debugPrint('Ask model uninstall failed: $e\n$st');
    }
    await FlutterEdgeAi.clearActiveInferenceIdentity();
  }

  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) async {
    await ensureInitialized();
    if (!await isModelReady()) {
      throw StateError('Ask model is not installed');
    }
    // Re-bind active identity if the process restarted with files still on disk.
    if (!FlutterEdgeAi.hasActiveModel()) {
      await installModel();
    }

    final model = await FlutterEdgeAi.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
    );
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
      return await session.getResponse();
    } finally {
      await session.close();
      await model.close();
    }
  }
}
