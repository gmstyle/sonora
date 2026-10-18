import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

import '../../../core/constants/ai_constants.dart';

/// Thin Genkit wrapper for Gemini Developer API (user-supplied API key).
class GeminiLlmDatasource {
  String? _apiKey;
  Genkit? _ai;

  void configure({required String? apiKey}) {
    final key = apiKey?.trim();
    if (key == null || key.isEmpty) {
      _apiKey = null;
      _ai = null;
      return;
    }
    if (_apiKey == key && _ai != null) return;
    _apiKey = key;
    _ai = Genkit(plugins: [googleAI(apiKey: key)]);
  }

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
  }) async {
    final ai = _ai;
    if (ai == null || !hasApiKey) {
      throw StateError('Gemini API key is not configured');
    }

    debugPrint('GeminiLlm: generate…');
    // Flash-latest uses thinking by default; with a small maxOutputTokens
    // budget the visible answer is truncated mid-JSON (e.g. 16 chars).
    final response = await ai
        .generate(
          model: googleAI.gemini(kAskGeminiModelId),
          system: systemInstruction,
          prompt: userMessage,
          config: GeminiOptions(
            maxOutputTokens: maxOutputTokens,
            thinkingConfig: GeminiThinkingConfig(thinkingBudget: 0),
            responseMimeType: 'application/json',
          ),
        )
        .timeout(kAskGeminiTimeout);
    final text = response.text.trim();
    debugPrint('GeminiLlm: generate done (${text.length} chars)');
    if (text.isEmpty) {
      throw StateError('Gemini returned empty text');
    }
    return text;
  }
}
