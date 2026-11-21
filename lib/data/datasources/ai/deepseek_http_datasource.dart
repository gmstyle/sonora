import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/ai_constants.dart';
import '../../../domain/models/ask_chat_models.dart';
import '../../../domain/models/grounded_llm_result.dart';
import '../../../domain/repositories/llm_chat_repository.dart';
import '../../../domain/usecases/ai/dsml_parser.dart';

export '../../../domain/usecases/ai/dsml_parser.dart';

class DeepSeekEndpointConfig {
  const DeepSeekEndpointConfig({
    this.proxyBaseUrl = '',
    this.byokApiKey = '',
    this.installId = '',
    this.model = kDeepSeekModelId,
  });

  final String proxyBaseUrl;
  final String byokApiKey;
  final String installId;
  final String model;

  String get normalizedProxyBaseUrl {
    var trimmed = proxyBaseUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  AskBackendMode get mode {
    if (byokApiKey.trim().isNotEmpty) return AskBackendMode.byok;
    if (normalizedProxyBaseUrl.isNotEmpty) return AskBackendMode.proxy;
    return AskBackendMode.unconfigured;
  }

  bool get isReady => mode != AskBackendMode.unconfigured;
}

class DeepSeekApiException implements Exception {
  const DeepSeekApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'DeepSeekApiException($statusCode): $message';
}

/// HTTP datasource talking OpenAI-compatible Chat Completions to either the
/// managed Cloudflare Ask proxy or directly to `api.deepseek.com` (BYOK).
class DeepSeekHttpDatasource {
  DeepSeekHttpDatasource({Dio? dio, required this.readConfig})
    : _dio = dio ?? Dio();

  final Dio _dio;
  final DeepSeekEndpointConfig Function() readConfig;

  Future<bool> isReady() async => readConfig().isReady;

  Future<AskQuotaInfo?> fetchQuota() async {
    final config = readConfig();
    switch (config.mode) {
      case AskBackendMode.byok:
        return AskQuotaInfo.unlimited();
      case AskBackendMode.unconfigured:
        return AskQuotaInfo.unconfigured();
      case AskBackendMode.proxy:
        if (config.installId.trim().isEmpty) {
          return AskQuotaInfo.unconfigured();
        }
        try {
          final response = await _dio.get<dynamic>(
            '${config.normalizedProxyBaseUrl}/v1/quota',
            options: Options(
              headers: {'X-Sonora-Install-Id': config.installId.trim()},
              sendTimeout: kAskTimeout,
              receiveTimeout: kAskTimeout,
              validateStatus: (_) => true,
            ),
          );
          final data = _asMap(response.data);
          final configured = data['configured'] != false;
          final fromHeaders = _parseQuotaHeaders(
            response.headers,
            configured: configured,
          );
          if (fromHeaders != null) return fromHeaders;
          final remaining = (data['remaining'] as num?)?.toInt();
          final limit = (data['limit'] as num?)?.toInt();
          if (remaining != null && limit != null) {
            return AskQuotaInfo(
              remaining: remaining,
              limit: limit,
              resetAt: DateTime.tryParse(data['resetAt']?.toString() ?? ''),
              isConfigured: configured,
            );
          }
          return null;
        } catch (_) {
          return null;
        }
    }
  }

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
    final config = readConfig();
    switch (config.mode) {
      case AskBackendMode.unconfigured:
        throw const AskNotConfiguredException();
      case AskBackendMode.byok:
        return _completeDirectByok(
          config: config,
          action: action,
          messages: messages,
          systemInstruction: systemInstruction,
          tools: tools,
          toolChoice: toolChoice,
          enableWebSearch: enableWebSearch,
          jsonMode: jsonMode,
          maxOutputTokens: maxOutputTokens,
        );
      case AskBackendMode.proxy:
        return _completeManagedProxy(
          config: config,
          action: action,
          messages: messages,
          locale: locale,
          tools: tools,
          toolChoice: toolChoice,
          enableWebSearch: enableWebSearch,
          maxOutputTokens: maxOutputTokens,
          turnId: turnId,
        );
    }
  }

  Future<LlmChatResponse> _completeDirectByok({
    required DeepSeekEndpointConfig config,
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    required String? systemInstruction,
    required List<LlmToolDefinition> tools,
    required String? toolChoice,
    required bool enableWebSearch,
    required bool jsonMode,
    required int maxOutputTokens,
  }) async {
    final wireMessages = <Map<String, dynamic>>[];
    final sys = systemInstruction?.trim() ?? '';
    if (sys.isNotEmpty) {
      wireMessages.add({'role': 'system', 'content': sys});
    }
    for (final msg in messages) {
      if (msg.role == 'system') continue;
      wireMessages.add(msg.toOpenAiJson());
    }

    final wireTools = <Map<String, dynamic>>[
      for (final tool in tools) tool.toOpenAiJson(),
      if (enableWebSearch || action == AskActionKind.trackInsights)
        {'type': 'deepseek_web_search', 'name': 'deepseek_web_search'},
    ];

    final payload = <String, dynamic>{
      'model': config.model.isEmpty ? kDeepSeekModelId : config.model,
      'messages': wireMessages,
      'thinking': {'type': 'disabled'},
      'max_tokens': maxOutputTokens,
      'temperature': _temperatureFor(action),
    };
    if (wireTools.isNotEmpty) {
      payload['tools'] = wireTools;
      if (toolChoice == 'none' || toolChoice == 'auto') {
        payload['tool_choice'] = toolChoice;
      }
    }
    // DeepSeek API: do not combine response_format json_object with tools.
    if (jsonMode && wireTools.isEmpty) {
      payload['response_format'] = {'type': 'json_object'};
    }

    final response = await _dio.post<dynamic>(
      '$kDeepSeekDirectBaseUrl/chat/completions',
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.byokApiKey.trim()}',
        },
        sendTimeout: kAskTimeout,
        receiveTimeout: kAskTimeout,
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 500;
    final raw = _asMap(response.data);
    if (status < 200 || status >= 300) {
      final errMsg = _extractErrorMessage(raw, status);
      throw DeepSeekApiException(status, errMsg);
    }

    return _parseChatResponse(
      raw,
      quota: AskQuotaInfo.unlimited(),
      allowDsmlToolFallback: toolChoice != 'none',
    );
  }

  Future<LlmChatResponse> _completeManagedProxy({
    required DeepSeekEndpointConfig config,
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    required String locale,
    required List<LlmToolDefinition> tools,
    required String? toolChoice,
    required bool enableWebSearch,
    required int maxOutputTokens,
    required String? turnId,
  }) async {
    final wireMessages = messages
        .where((m) => m.role != 'system')
        .map((m) => m.toOpenAiJson())
        .toList(growable: false);

    final payload = <String, dynamic>{
      'action': action.wireName,
      'locale': locale.trim().isEmpty ? 'en' : locale.trim(),
      'messages': wireMessages,
      'maxOutputTokens': maxOutputTokens,
      if (tools.isNotEmpty)
        'tools': tools.map((t) => t.toOpenAiJson()).toList(growable: false),
      if (tools.isNotEmpty && (toolChoice == 'none' || toolChoice == 'auto'))
        'toolChoice': toolChoice,
      if (enableWebSearch) 'enableWebSearch': true,
      if (turnId != null && turnId.trim().isNotEmpty) 'turnId': turnId.trim(),
    };

    final response = await _dio.post<dynamic>(
      '${config.normalizedProxyBaseUrl}/v1/ask',
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Sonora-Install-Id': config.installId.trim(),
        },
        sendTimeout: kAskTimeout,
        receiveTimeout: kAskTimeout,
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 500;
    final raw = _asMap(response.data);
    final quota =
        _parseQuotaHeaders(response.headers, configured: true) ??
        _parseQuotaBody(raw);

    if (status == 429) {
      throw AskQuotaExceededException(
        quota ?? const AskQuotaInfo(remaining: 0, limit: kAskDailyCreditLimit),
        _extractErrorMessage(raw, status),
      );
    }
    if (status < 200 || status >= 300) {
      throw DeepSeekApiException(status, _extractErrorMessage(raw, status));
    }

    return _parseChatResponse(
      raw,
      quota: quota,
      allowDsmlToolFallback: toolChoice != 'none',
    );
  }

  LlmChatResponse _parseChatResponse(
    Map<String, dynamic> raw, {
    AskQuotaInfo? quota,
    bool allowDsmlToolFallback = true,
  }) {
    final choices = raw['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const DeepSeekApiException(502, 'Empty response choices');
    }
    final first = Map<String, dynamic>.from(choices.first as Map);
    final messageRaw = first['message'];
    if (messageRaw is! Map) {
      throw const DeepSeekApiException(502, 'Missing choice message');
    }
    final message = Map<String, dynamic>.from(messageRaw);
    final rawContent = message['content']?.toString() ?? '';

    final toolCalls = <AskToolCall>[];
    final seenIds = <String>{};
    final rawToolCalls = message['tool_calls'];
    if (rawToolCalls is List) {
      for (var i = 0; i < rawToolCalls.length; i++) {
        final item = rawToolCalls[i];
        if (item is! Map) continue;
        final fn = item['function'];
        if (fn is! Map) continue;
        final name = fn['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final id = item['id']?.toString().trim();
        final baseId = (id == null || id.isEmpty) ? 'call_$i' : id;
        var uniqueId = baseId;
        var suffix = 1;
        while (!seenIds.add(uniqueId)) {
          uniqueId = '${baseId}_$suffix';
          suffix++;
        }
        final args = _decodeArgs(fn['arguments']);
        toolCalls.add(AskToolCall(id: uniqueId, name: name, arguments: args));
      }
    }

    final dsml = parseAndStripDsml(rawContent, idStartIndex: toolCalls.length);
    if (toolCalls.isEmpty &&
        allowDsmlToolFallback &&
        dsml.toolCalls.isNotEmpty) {
      toolCalls.addAll(dsml.toolCalls);
    }

    final serverToolCalls = <Map<String, dynamic>>[];
    final rawServerCalls = message['server_tool_calls'];
    if (rawServerCalls is List) {
      for (final entry in rawServerCalls) {
        if (entry is Map) {
          serverToolCalls.add(Map<String, dynamic>.from(entry));
        }
      }
    }

    return LlmChatResponse(
      content: dsml.cleanContent,
      toolCalls: toolCalls,
      sources: extractGroundedSources(raw),
      quota: quota,
      serverToolCalls: serverToolCalls,
    );
  }

  static double _temperatureFor(AskActionKind action) {
    switch (action) {
      case AskActionKind.chat:
      case AskActionKind.wrapped:
      case AskActionKind.pulseDrop:
        return 0.5;
      case AskActionKind.mixIntent:
      case AskActionKind.searchIntent:
      case AskActionKind.trackInsights:
      case AskActionKind.lyricsTranslate:
      case AskActionKind.spotifyMatch:
        return 0.2;
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Return empty map; status handler supplies message.
      }
    }
    return const {};
  }

  static Map<String, dynamic> _decodeArgs(dynamic rawArgs) {
    if (rawArgs is Map<String, dynamic>) return rawArgs;
    if (rawArgs is Map) return Map<String, dynamic>.from(rawArgs);
    if (rawArgs is String && rawArgs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  static AskQuotaInfo? _parseQuotaHeaders(
    Headers headers, {
    required bool configured,
  }) {
    final remStr = headers.value('x-ask-quota-remaining');
    final limStr = headers.value('x-ask-quota-limit');
    if (remStr == null || limStr == null) return null;
    final rem = int.tryParse(remStr);
    final lim = int.tryParse(limStr);
    if (rem == null || lim == null) return null;
    return AskQuotaInfo(
      remaining: rem,
      limit: lim,
      resetAt: DateTime.tryParse(headers.value('x-ask-quota-reset') ?? ''),
      isConfigured: configured,
    );
  }

  static AskQuotaInfo? _parseQuotaBody(Map<String, dynamic> raw) {
    final rem = (raw['remaining'] as num?)?.toInt();
    final lim = (raw['limit'] as num?)?.toInt();
    if (rem == null || lim == null) return null;
    return AskQuotaInfo(
      remaining: rem,
      limit: lim,
      resetAt: DateTime.tryParse(raw['resetAt']?.toString() ?? ''),
      isConfigured: true,
    );
  }

  static String _extractErrorMessage(Map<String, dynamic> raw, int status) {
    final err = raw['error'];
    if (err is Map && err['message'] != null) {
      return err['message'].toString();
    }
    if (err != null) return err.toString();
    return 'HTTP $status';
  }
}
