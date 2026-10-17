/// On-device LLM used for Ask search (and future AI features).
///
/// Implementations wrap a Flutter/native runtime; this interface stays pure Dart.
abstract class OnDeviceLlmRepository {
  /// True when the Ask model file is installed and set active.
  Future<bool> isModelReady();

  /// Download and activate the Ask model. [onProgress] is 0.0–1.0.
  Future<void> installModel({void Function(double progress)? onProgress});

  /// Remove the Ask model from local storage.
  Future<void> uninstallModel();

  /// One-shot completion with a system instruction. Returns assistant text.
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  });
}
