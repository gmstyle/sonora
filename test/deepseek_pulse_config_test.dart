import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/ai/deepseek_http_datasource.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  int calls = 0;
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    lastOptions = options;
    return onFetch(options);
  }
}

void main() {
  test(
    'parses GET /v1/pulse/config JSON including editorialPulse in proxy mode',
    () async {
      final adapter = _MockAdapter((options) async {
        final body = jsonEncode({
          'enabled': true,
          'cooldownHours': 48,
          'quietHoursStart': 22,
          'quietHoursEnd': 9,
          'weeklyRemaining': 2,
          'weeklyLimit': 3,
          'enabledTriggers': ['new_release', 'editorial_pulse'],
          'editorialPulse': {
            'id': 'editorial:2026-W47:2026-11-24:it',
            'theme': 'Nuove uscite',
            'hook': 'Venerdì di scoperte',
            'moodKeywords': ['indie', 'synth'],
            'promptAngle': 'Novità fresche',
            'generatedAt': '2026-11-24T06:00:00.000Z',
          },
        });
        return ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final ds = DeepSeekHttpDatasource(
        dio: dio,
        readConfig: () => const DeepSeekEndpointConfig(
          proxyBaseUrl: 'https://example.workers.dev/',
          installId: 'install_12345678',
        ),
      );

      final config = await ds.fetchPulseConfig(locale: 'it');
      expect(config, isNotNull);
      expect(config!.enabled, isTrue);
      expect(config.cooldownHours, 48);
      expect(config.weeklyRemaining, 2);
      expect(config.isTriggerEnabled('new_release'), isTrue);
      expect(config.isTriggerEnabled('comeback_mix'), isFalse);
      expect(config.editorialPulse, isNotNull);
      expect(config.editorialPulse!.theme, 'Nuove uscite');
      expect(adapter.lastOptions?.uri.path, '/v1/pulse/config');
      expect(adapter.lastOptions?.uri.queryParameters['locale'], 'it');
      expect(
        adapter.lastOptions?.headers['X-Sonora-Install-Id'],
        'install_12345678',
      );
    },
  );

  test('returns defaults in BYOK mode without hitting network', () async {
    final adapter = _MockAdapter((_) async => throw StateError('unexpected'));
    final dio = Dio()..httpClientAdapter = adapter;
    final ds = DeepSeekHttpDatasource(
      dio: dio,
      readConfig: () => const DeepSeekEndpointConfig(byokApiKey: 'sk-test'),
    );

    final config = await ds.fetchPulseConfig(locale: 'en');
    expect(config, isNotNull);
    expect(config!.enabled, isTrue);
    expect(adapter.calls, 0);
  });

  test('returns null when unconfigured or server returns HTTP 500', () async {
    final unconfigured = DeepSeekHttpDatasource(
      dio: Dio(),
      readConfig: () => const DeepSeekEndpointConfig(),
    );
    expect(await unconfigured.fetchPulseConfig(locale: 'en'), isNull);

    final failingAdapter = _MockAdapter((_) async {
      return ResponseBody.fromString('{"error":"boom"}', 500);
    });
    final failingDs = DeepSeekHttpDatasource(
      dio: Dio()..httpClientAdapter = failingAdapter,
      readConfig: () => const DeepSeekEndpointConfig(
        proxyBaseUrl: 'https://example.workers.dev',
        installId: 'install_12345678',
      ),
    );
    expect(await failingDs.fetchPulseConfig(locale: 'en'), isNull);
  });
}
