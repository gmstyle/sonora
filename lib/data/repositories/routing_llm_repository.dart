import '../../domain/models/ask_mode.dart';
import '../../domain/repositories/llm_completion_repository.dart';
import '../../domain/repositories/on_device_llm_repository.dart';
import 'gemini_llm_repository_impl.dart';

/// Resolves On-device vs Cloud Ask and delegates [complete].
class RoutingLlmRepository implements LlmCompletionRepository {
  RoutingLlmRepository({
    required this._onDevice,
    required this._cloud,
    required this._mode,
    required this._apiKey,
    required this._isOffline,
  });

  final OnDeviceLlmRepository _onDevice;
  final GeminiLlmRepositoryImpl _cloud;
  final AskMode Function() _mode;
  final String? Function() _apiKey;
  final bool Function() _isOffline;

  /// Sync resolution helpers for unit tests / capabilities.
  static Future<AskLlmBackend> resolveBackend({
    required AskMode mode,
    required String? apiKey,
    required bool isOffline,
    required bool onDeviceReady,
  }) async {
    final keyOk = apiKey != null && apiKey.trim().isNotEmpty;
    final cloudOk = keyOk && !isOffline;

    return switch (mode) {
      AskMode.onDevice =>
        onDeviceReady ? AskLlmBackend.onDevice : AskLlmBackend.none,
      AskMode.cloud => cloudOk ? AskLlmBackend.cloud : AskLlmBackend.none,
      AskMode.auto =>
        cloudOk
            ? AskLlmBackend.cloud
            : (onDeviceReady ? AskLlmBackend.onDevice : AskLlmBackend.none),
    };
  }

  Future<AskLlmBackend> currentBackend() async {
    _cloud.configure(apiKey: _apiKey());
    final onDeviceReady = await _onDevice.isModelReady();
    return resolveBackend(
      mode: _mode(),
      apiKey: _apiKey(),
      isOffline: _isOffline(),
      onDeviceReady: onDeviceReady,
    );
  }

  @override
  Future<bool> isReady() async {
    final backend = await currentBackend();
    return backend != AskLlmBackend.none;
  }

  @override
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) async {
    final backend = await currentBackend();
    return switch (backend) {
      AskLlmBackend.cloud => _cloud.complete(
        systemInstruction: systemInstruction,
        userMessage: userMessage,
        maxOutputTokens: maxOutputTokens,
      ),
      AskLlmBackend.onDevice => _onDevice.complete(
        systemInstruction: systemInstruction,
        userMessage: userMessage,
        maxOutputTokens: maxOutputTokens,
      ),
      AskLlmBackend.none => throw StateError('Ask LLM is not ready'),
    };
  }
}
