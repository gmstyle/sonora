import '../../domain/repositories/llm_completion_repository.dart';
import '../datasources/ai/gemini_llm_datasource.dart';

/// Cloud Ask completion via Gemini (Genkit BYOK).
class GeminiLlmRepositoryImpl implements LlmCompletionRepository {
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
}
