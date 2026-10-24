import '../models/grounded_llm_result.dart';

/// Cloud-only completion with Google Search grounding (Gemini).
///
/// Not implemented by on-device Ask — callers must gate on cloud readiness.
abstract class GroundedLlmRepository {
  Future<bool> isReady();

  /// One-shot grounded completion. [sources] come from grounding metadata.
  Future<GroundedLlmResult> completeGrounded({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 1024,
  });
}
