import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/constants/ai_constants.dart';

/// Smoke contract for the Ask model artifact chosen in the AI UX plan.
void main() {
  test('Ask model points at litert-community Qwen3 dynamic INT4', () {
    expect(kAskLlmHfRepo, 'litert-community/Qwen3-0.6B');
    expect(kAskLlmFilename, 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm');
    expect(kAskLlmLegacyFilename, 'qwen3_0_6b_mixed_int4.litertlm');
    expect(kAskLlmDownloadUrl, contains(kAskLlmHfRepo));
    expect(kAskLlmDownloadUrl, contains(kAskLlmFilename));
    expect(kAskLlmDownloadUrl, startsWith('https://huggingface.co/'));
    expect(kAskLlmApproxSizeMb, greaterThan(300));
    expect(kAskLlmApproxSizeMb, lessThan(400));
  });
}
