/// How Ask picks an LLM backend.
enum AskMode {
  /// Always use the on-device Qwen pack when installed.
  onDevice,

  /// Always use Gemini with the user API key when online.
  cloud,

  /// Prefer Gemini when key + online; else on-device when installed.
  auto;

  static AskMode fromStorage(String? raw) {
    return switch (raw) {
      'cloud' => AskMode.cloud,
      'auto' => AskMode.auto,
      _ => AskMode.onDevice,
    };
  }

  String get storageValue => name;
}

/// Effective backend after resolving [AskMode] against readiness.
enum AskLlmBackend { none, onDevice, cloud }
