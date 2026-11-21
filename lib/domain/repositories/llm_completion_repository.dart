import '../models/ask_chat_models.dart';

/// Shared one-shot completion API for Ask.
///
/// Domain use cases depend on this — never on a specific HTTP client.
abstract class LlmCompletionRepository {
  /// True when a backend is available for [complete].
  Future<bool> isReady();

  /// One-shot completion with a system instruction. Returns assistant text.
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
    AskActionKind action = AskActionKind.chat,
    String locale = 'en',
    String? turnId,
  });
}
