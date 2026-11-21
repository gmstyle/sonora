import '../models/ask_chat_models.dart';
import '../models/grounded_llm_result.dart';

/// Completion with server-side web search grounding (DeepSeek web search).
abstract class GroundedLlmRepository {
  Future<bool> isReady();

  /// One-shot grounded completion. [sources] come from web search annotations.
  Future<GroundedLlmResult> completeGrounded({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 1024,
    AskActionKind action = AskActionKind.trackInsights,
    String locale = 'en',
    String? turnId,
  });
}
