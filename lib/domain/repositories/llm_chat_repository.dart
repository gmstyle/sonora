import '../models/ask_chat_models.dart';
import '../models/grounded_llm_result.dart';

/// A single turn message passed to/from the DeepSeek Chat Completions API.
class LlmChatMessage {
  const LlmChatMessage({
    required this.role,
    this.content,
    this.toolCalls = const [],
    this.toolCallId,
    this.name,
    this.serverToolCalls = const [],
  });

  final String role;
  final String? content;
  final List<AskToolCall> toolCalls;
  final String? toolCallId;
  final String? name;

  /// DeepSeek extension field for multi-turn web search continuity.
  final List<Map<String, dynamic>> serverToolCalls;

  Map<String, dynamic> toOpenAiJson() {
    final map = <String, dynamic>{'role': role};
    if (content != null || toolCalls.isNotEmpty) {
      map['content'] = content;
    }
    if (toolCalls.isNotEmpty) {
      map['tool_calls'] = toolCalls.map((t) => t.toOpenAiJson()).toList();
    }
    if (serverToolCalls.isNotEmpty) {
      map['server_tool_calls'] = serverToolCalls;
    }
    if (role == 'tool') {
      if (toolCallId != null) map['tool_call_id'] = toolCallId;
      if (name != null) map['name'] = name;
    }
    return map;
  }
}

/// JSON-schema tool declaration sent via `tools` in Chat Completions.
class LlmToolDefinition {
  const LlmToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toOpenAiJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class LlmChatResponse {
  const LlmChatResponse({
    this.content = '',
    this.toolCalls = const [],
    this.sources = const [],
    this.quota,
    this.serverToolCalls = const [],
  });

  final String content;
  final List<AskToolCall> toolCalls;
  final List<GroundedSource> sources;
  final AskQuotaInfo? quota;
  final List<Map<String, dynamic>> serverToolCalls;
}

/// Multi-turn chat + Function Calling contract for Sonora Ask.
abstract class LlmChatRepository {
  Future<bool> isReady();

  Future<AskQuotaInfo?> fetchQuota();

  Future<LlmChatResponse> completeChat({
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    String? systemInstruction,
    String locale = 'en',
    List<LlmToolDefinition> tools = const [],
    bool enableWebSearch = false,
    bool jsonMode = false,
    int maxOutputTokens = 900,
    String? turnId,
  });
}
