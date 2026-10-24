import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/repositories/routing_llm_repository.dart';
import 'package:sonora/domain/models/ask_capabilities.dart';
import 'package:sonora/domain/models/ask_mode.dart';

void main() {
  group('RoutingLlmRepository.resolveBackend', () {
    test('onDevice uses local when ready', () async {
      final b = await RoutingLlmRepository.resolveBackend(
        mode: AskMode.onDevice,
        apiKey: 'secret',
        isOffline: false,
        onDeviceReady: true,
      );
      expect(b, AskLlmBackend.onDevice);
    });

    test('onDevice is none without model', () async {
      final b = await RoutingLlmRepository.resolveBackend(
        mode: AskMode.onDevice,
        apiKey: 'secret',
        isOffline: false,
        onDeviceReady: false,
      );
      expect(b, AskLlmBackend.none);
    });

    test('cloud uses Gemini when key and online', () async {
      final b = await RoutingLlmRepository.resolveBackend(
        mode: AskMode.cloud,
        apiKey: 'secret',
        isOffline: false,
        onDeviceReady: true,
      );
      expect(b, AskLlmBackend.cloud);
    });

    test('cloud is none offline', () async {
      final b = await RoutingLlmRepository.resolveBackend(
        mode: AskMode.cloud,
        apiKey: 'secret',
        isOffline: true,
        onDeviceReady: true,
      );
      expect(b, AskLlmBackend.none);
    });

    test('auto prefers cloud then falls back to on-device', () async {
      final cloud = await RoutingLlmRepository.resolveBackend(
        mode: AskMode.auto,
        apiKey: 'secret',
        isOffline: false,
        onDeviceReady: true,
      );
      expect(cloud, AskLlmBackend.cloud);

      final local = await RoutingLlmRepository.resolveBackend(
        mode: AskMode.auto,
        apiKey: 'secret',
        isOffline: true,
        onDeviceReady: true,
      );
      expect(local, AskLlmBackend.onDevice);
    });
  });

  group('AskCapabilities', () {
    test('wrapped only on cloud', () {
      expect(
        const AskCapabilities(AskLlmBackend.none).canWrappedNarrative,
        isFalse,
      );
      expect(
        const AskCapabilities(AskLlmBackend.onDevice).canWrappedNarrative,
        isFalse,
      );
      expect(
        const AskCapabilities(AskLlmBackend.cloud).canWrappedNarrative,
        isTrue,
      );
      expect(
        const AskCapabilities(AskLlmBackend.onDevice).canMomentMix,
        isTrue,
      );
    });

    test('player insights only on cloud', () {
      expect(
        const AskCapabilities(AskLlmBackend.none).canPlayerInsights,
        isFalse,
      );
      expect(
        const AskCapabilities(AskLlmBackend.onDevice).canPlayerInsights,
        isFalse,
      );
      expect(
        const AskCapabilities(AskLlmBackend.cloud).canPlayerInsights,
        isTrue,
      );
    });
  });
}
