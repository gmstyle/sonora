import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/ai/deepseek_http_datasource.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/grounded_llm_result.dart';
import 'package:sonora/domain/repositories/llm_chat_repository.dart';

class _CapturedRequest {
  _CapturedRequest(this.options, this.data);
  final RequestOptions options;
  final Map<String, dynamic>? data;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<_CapturedRequest> captured = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic>? bodyMap;
    if (options.data is Map) {
      bodyMap = Map<String, dynamic>.from(options.data as Map);
    }
    captured.add(_CapturedRequest(options, bodyMap));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(
  Object body, {
  int statusCode = 200,
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      ...headers,
    },
  );
}

void main() {
  group('DeepSeekHttpDatasource', () {
    test('proxy mode sends X-Sonora-Install-Id, strips system roles, and parses quota headers', () async {
      final adapter = _StubAdapter(
        (_) async => _jsonResponse(
          {
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'Ciao!'},
              },
            ],
          },
          headers: {
            'x-ask-quota-remaining': ['29'],
            'x-ask-quota-limit': ['30'],
            'x-ask-quota-reset': ['2026-11-22T00:00:00.000Z'],
          },
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = DeepSeekHttpDatasource(
        dio: dio,
        readConfig: () => const DeepSeekEndpointConfig(
          proxyBaseUrl: 'https://ask.sonora.workers.dev/',
          installId: 'install_1234567890',
        ),
      );

      final res = await ds.completeChat(
        action: AskActionKind.chat,
        locale: 'it',
        turnId: 'turn_1',
        messages: const [
          LlmChatMessage(role: 'system', content: 'CLIENT SYSTEM INJECT'),
          LlmChatMessage(role: 'user', content: 'Consigliami un mix chill'),
        ],
      );

      expect(res.content, 'Ciao!');
      expect(res.quota?.remaining, 29);
      expect(res.quota?.limit, 30);

      final req = adapter.captured.single;
      expect(
        req.options.uri.toString(),
        'https://ask.sonora.workers.dev/v1/ask',
      );
      expect(req.options.headers['X-Sonora-Install-Id'], 'install_1234567890');
      expect(req.data!['action'], 'chat');
      expect(req.data!['locale'], 'it');
      expect(req.data!['turnId'], 'turn_1');
      final sentMsgs = req.data!['messages'] as List;
      expect(sentMsgs, hasLength(1));
      expect((sentMsgs.single as Map)['role'], 'user');
    });

    test(
      'proxy 429 throws AskQuotaExceededException with quota info',
      () async {
        final adapter = _StubAdapter(
          (_) async => _jsonResponse(
            {
              'error': 'device_quota_exceeded',
              'remaining': 0,
              'limit': 30,
              'resetAt': '2026-11-22T00:00:00.000Z',
            },
            statusCode: 429,
            headers: {
              'x-ask-quota-remaining': ['0'],
              'x-ask-quota-limit': ['30'],
            },
          ),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final ds = DeepSeekHttpDatasource(
          dio: dio,
          readConfig: () => const DeepSeekEndpointConfig(
            proxyBaseUrl: 'https://ask.sonora.workers.dev',
            installId: 'install_1234567890',
          ),
        );

        await expectLater(
          () => ds.completeChat(
            action: AskActionKind.chat,
            messages: const [LlmChatMessage(role: 'user', content: 'hi')],
          ),
          throwsA(
            isA<AskQuotaExceededException>()
                .having((e) => e.quota.remaining, 'remaining', 0)
                .having((e) => e.quota.isExhausted, 'isExhausted', isTrue),
          ),
        );
      },
    );

    test('BYOK mode disables thinking and omits response_format when deepseek_web_search is attached', () async {
      final adapter = _StubAdapter(
        (_) async => _jsonResponse({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': '{"bullets":["Registrato nel 1972."]}',
                'annotations': [
                  {
                    'type': 'citation',
                    'url':
                        'https://en.wikipedia.org/wiki/Time_(Pink_Floyd_song)',
                    'title': 'Time - Wikipedia',
                  },
                ],
              },
            },
          ],
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = DeepSeekHttpDatasource(
        dio: dio,
        readConfig: () =>
            const DeepSeekEndpointConfig(byokApiKey: 'sk-byok-secret'),
      );

      final res = await ds.completeChat(
        action: AskActionKind.trackInsights,
        systemInstruction: 'Return JSON bullets.',
        jsonMode: true,
        enableWebSearch: true,
        messages: const [LlmChatMessage(role: 'user', content: 'Time')],
      );

      expect(res.quota?.isUnlimited, isTrue);
      expect(res.sources, hasLength(1));
      expect(res.sources.single.displayTitle, 'Time - Wikipedia');

      final req = adapter.captured.single;
      expect(
        req.options.uri.toString(),
        'https://api.deepseek.com/chat/completions',
      );
      expect(req.options.headers['Authorization'], 'Bearer sk-byok-secret');
      expect(req.data!['model'], 'deepseek-flash');
      expect(req.data!['thinking'], {'type': 'disabled'});
      expect(req.data!['tools'], [
        {'type': 'deepseek_web_search', 'name': 'deepseek_web_search'},
      ]);
      expect(req.data!.containsKey('response_format'), isFalse);
    });

    test('BYOK mode without tools includes response_format json_object when jsonMode is true', () async {
      final adapter = _StubAdapter(
        (_) async => _jsonResponse({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': '{"decisions":[]}'},
            },
          ],
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = DeepSeekHttpDatasource(
        dio: dio,
        readConfig: () => const DeepSeekEndpointConfig(byokApiKey: 'sk-key'),
      );

      await ds.completeChat(
        action: AskActionKind.spotifyMatch,
        systemInstruction: 'Return JSON.',
        jsonMode: true,
        messages: const [LlmChatMessage(role: 'user', content: '{}')],
      );

      expect(adapter.captured.single.data!['response_format'], {
        'type': 'json_object',
      });
    });
  });

  group('extractGroundedSources DeepSeek extensions', () {
    test(
      'parses annotations, url_citation, server_tool_calls, and citations',
      () {
        final sources = extractGroundedSources({
          'choices': [
            {
              'message': {
                'annotations': [
                  {
                    'type': 'citation',
                    'url': 'https://a.example/1',
                    'title': 'One',
                  },
                  {
                    'type': 'url_citation',
                    'url_citation': {
                      'url': 'https://b.example/2',
                      'title': 'Two',
                    },
                  },
                  {
                    'type': 'citation',
                    'url': 'https://a.example/1',
                    'title': 'Dup',
                  },
                ],
                'server_tool_calls': [
                  {
                    'results': [
                      {'link': 'https://c.example/3', 'title': 'Three'},
                    ],
                  },
                ],
              },
            },
          ],
          'citations': ['https://d.example/4'],
        });

        expect(sources.map((s) => s.uri), [
          'https://a.example/1',
          'https://b.example/2',
          'https://c.example/3',
          'https://d.example/4',
        ]);
        expect(sources.first.displayTitle, 'One');
        expect(sources.last.displayTitle, 'd.example');
      },
    );
  });
}
