import '../../domain/models/grounded_llm_result.dart';
import '../../domain/repositories/grounded_llm_repository.dart';
import '../../domain/repositories/llm_completion_repository.dart';
import '../datasources/ai/gemini_llm_datasource.dart';

/// Cloud Ask completion via Gemini (Genkit BYOK).
class GeminiLlmRepositoryImpl
    implements LlmCompletionRepository, GroundedLlmRepository {
  GeminiLlmRepositoryImpl(this._datasource);

  final GeminiLlmDatasource _datasource;

  void configure({required String? apiKey}) {
    _datasource.configure(apiKey: apiKey);
  }

  @override
  Future<bool> isReady() async => _datasource.hasApiKey;

  @override
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) {
    return _datasource.complete(
      systemInstruction: systemInstruction,
      userMessage: userMessage,
      maxOutputTokens: maxOutputTokens,
    );
  }

  @override
  Future<GroundedLlmResult> completeGrounded({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 1024,
  }) {
    return _datasource.completeGrounded(
      systemInstruction: systemInstruction,
      userMessage: userMessage,
      maxOutputTokens: maxOutputTokens,
    );
  }
}
