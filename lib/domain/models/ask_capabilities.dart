import 'ask_mode.dart';

/// Feature gates derived from the resolved Ask LLM backend.
class AskCapabilities {
  const AskCapabilities(this.backend);

  final AskLlmBackend backend;

  bool get hasLlm => backend != AskLlmBackend.none;

  bool get canInterpretSearch => hasLlm;

  bool get canMomentMix => hasLlm;

  bool get canRewriteImport => hasLlm;

  /// Prose narrative — cloud only (on-device quality is insufficient).
  bool get canWrappedNarrative => backend == AskLlmBackend.cloud;

  /// Player curiosities (Search grounding) + lyrics translation — cloud only.
  bool get canPlayerInsights => backend == AskLlmBackend.cloud;
}
