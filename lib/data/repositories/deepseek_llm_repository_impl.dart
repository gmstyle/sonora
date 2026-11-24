import '../../domain/models/ask_chat_models.dart';
import '../../domain/models/grounded_llm_result.dart';
import '../../domain/repositories/grounded_llm_repository.dart';
import '../../domain/repositories/llm_chat_repository.dart';
import '../../domain/repositories/llm_completion_repository.dart';
import '../datasources/ai/deepseek_http_datasource.dart';

class DeepSeekLlmRepositoryImpl
    implements
        LlmCompletionRepository,
        GroundedLlmRepository,
        LlmChatRepository {
  DeepSeekLlmRepositoryImpl(this._datasource, {this.onQuotaUpdated});

  final DeepSeekHttpDatasource _datasource;
  final void Function(AskQuotaInfo quota)? onQuotaUpdated;

  @override
  Future<bool> isReady() => _datasource.isReady();

  @override
  Future<AskQuotaInfo?> fetchQuota() async {
    final quota = await _datasource.fetchQuota();
    if (quota != null) {
      onQuotaUpdated?.call(quota);
    }
    return quota;
  }

  @override
  Future<AskPulseRemoteConfig?> fetchPulseConfig({required String locale}) {
    return _datasource.fetchPulseConfig(locale: locale);
  }

  @override
  Future<String> complete({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 256,
    AskActionKind action = AskActionKind.chat,
    String locale = 'en',
    String? turnId,
  }) async {
    final jsonMode =
        action != AskActionKind.chat && action != AskActionKind.trackInsights;
    final res = await _datasource.completeChat(
      action: action,
      messages: [LlmChatMessage(role: 'user', content: userMessage)],
      systemInstruction: systemInstruction,
      locale: locale,
      jsonMode: jsonMode,
      maxOutputTokens: maxOutputTokens,
      turnId: turnId,
    );
    if (res.quota != null) {
      onQuotaUpdated?.call(res.quota!);
    }
    return res.content;
  }

  @override
  Future<GroundedLlmResult> completeGrounded({
    required String systemInstruction,
    required String userMessage,
    int maxOutputTokens = 1024,
    AskActionKind action = AskActionKind.trackInsights,
    String locale = 'en',
    String? turnId,
  }) async {
    final res = await _datasource.completeChat(
      action: action,
      messages: [LlmChatMessage(role: 'user', content: userMessage)],
      systemInstruction: systemInstruction,
      locale: locale,
      enableWebSearch: true,
      jsonMode: false,
      maxOutputTokens: maxOutputTokens,
      turnId: turnId,
    );
    if (res.quota != null) {
      onQuotaUpdated?.call(res.quota!);
    }
    return GroundedLlmResult(text: res.content, sources: res.sources);
  }

  @override
  Future<LlmChatResponse> completeChat({
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    String? systemInstruction,
    String locale = 'en',
    List<LlmToolDefinition> tools = const [],
    String? toolChoice,
    bool enableWebSearch = false,
    bool jsonMode = false,
    int maxOutputTokens = 900,
    String? turnId,
  }) async {
    try {
      final res = await _datasource.completeChat(
        action: action,
        messages: messages,
        systemInstruction: systemInstruction,
        locale: locale,
        tools: tools,
        toolChoice: toolChoice,
        enableWebSearch: enableWebSearch,
        jsonMode: jsonMode,
        maxOutputTokens: maxOutputTokens,
        turnId: turnId,
      );
      if (res.quota != null) {
        onQuotaUpdated?.call(res.quota!);
      }
      return res;
    } on AskQuotaExceededException catch (e) {
      onQuotaUpdated?.call(e.quota);
      rethrow;
    }
  }
}
