import 'dart:convert';

import '../../models/ask_chat_models.dart';

class ParsedDsmlResult {
  const ParsedDsmlResult({required this.cleanContent, required this.toolCalls});

  final String cleanContent;
  final List<AskToolCall> toolCalls;
}

final _dsmlPresenceRe = RegExp(
  r'</?[\uFF5C|]+\s*DSML\s*[\uFF5C|]+',
  caseSensitive: false,
);
final _dsmlCallsBlockRe = RegExp(
  r'<[\uFF5C|]+\s*DSML\s*[\uFF5C|]+\s*(?:function_|tool_)?calls\b[^>]*>[\s\S]*?</[\uFF5C|]+\s*DSML\s*[\uFF5C|]+\s*(?:function_|tool_)?calls>',
  caseSensitive: false,
);
final _dsmlInvokeBlockRe = RegExp(
  r'<[\uFF5C|]+\s*DSML\s*[\uFF5C|]+\s*invoke\s+name="([^"]+)"\s*>([\s\S]*?)</[\uFF5C|]+\s*DSML\s*[\uFF5C|]+\s*invoke>',
  caseSensitive: false,
);
final _dsmlParamRe = RegExp(
  r'<[\uFF5C|]+\s*DSML\s*[\uFF5C|]+\s*parameter\s+name="([^"]+)"(?:\s+string="(true|false)")?\s*>([\s\S]*?)</[\uFF5C|]+\s*DSML\s*[\uFF5C|]+\s*parameter>',
  caseSensitive: false,
);
final _dsmlAnyTagRe = RegExp(
  r'</?[\uFF5C|]+\s*DSML\s*[\uFF5C|]+[^>]*>',
  caseSensitive: false,
);
final _dsmlTrailingUnclosedRe = RegExp(
  r'<[\uFF5C|]+\s*DSML\s*[\uFF5C|]+[\s\S]*$',
  caseSensitive: false,
);

/// Extracts leaked DeepSeek DSML tool invocations from raw assistant `content`
/// and removes all DSML markup so internal tags never reach the chat UI.
ParsedDsmlResult parseAndStripDsml(String raw, {int idStartIndex = 0}) {
  if (!_dsmlPresenceRe.hasMatch(raw)) {
    return ParsedDsmlResult(cleanContent: raw, toolCalls: const []);
  }

  final calls = <AskToolCall>[];
  for (final invokeMatch in _dsmlInvokeBlockRe.allMatches(raw)) {
    final toolName = (invokeMatch.group(1) ?? '').trim();
    if (toolName.isEmpty) continue;
    final inner = invokeMatch.group(2) ?? '';
    final args = <String, dynamic>{};

    for (final paramMatch in _dsmlParamRe.allMatches(inner)) {
      final paramName = (paramMatch.group(1) ?? '').trim();
      if (paramName.isEmpty) continue;
      final isString = paramMatch.group(2)?.toLowerCase();
      final valRaw = paramMatch.group(3) ?? '';

      if (isString == 'false') {
        final trimmed = valRaw.trim();
        try {
          args[paramName] = jsonDecode(trimmed);
        } catch (_) {
          args[paramName] = trimmed;
        }
      } else {
        args[paramName] = valRaw;
      }
    }

    calls.add(
      AskToolCall(
        id: 'dsml_${idStartIndex + calls.length}',
        name: toolName,
        arguments: args,
      ),
    );
  }

  final cleaned = raw
      .replaceAll(_dsmlCallsBlockRe, '')
      .replaceAll(_dsmlInvokeBlockRe, '')
      .replaceAll(_dsmlTrailingUnclosedRe, '')
      .replaceAll(_dsmlAnyTagRe, '')
      .trim();

  return ParsedDsmlResult(
    cleanContent: cleaned,
    toolCalls: List.unmodifiable(calls),
  );
}
