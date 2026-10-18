import 'llm_completion_repository.dart';

/// On-device Ask model (LiteRT-LM). Install/warm APIs stay here;
/// [complete] is shared via [LlmCompletionRepository].
abstract class OnDeviceLlmRepository implements LlmCompletionRepository {
  /// True when the Ask model file is installed and set active.
  Future<bool> isModelReady();

  /// Download and activate the Ask model. [onProgress] is 0.0–1.0.
  Future<void> installModel({void Function(double progress)? onProgress});

  /// Remove the Ask model from local storage.
  Future<void> uninstallModel();

  /// Load model weights into memory (no-op if already warm).
  Future<void> warmUp();
}
