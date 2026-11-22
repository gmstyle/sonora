import 'ask_chat_models.dart';

/// Feature gates derived from the resolved Ask backend and network state.
class AskCapabilities {
  const AskCapabilities({required this.backend, required this.isOffline});

  final AskBackendMode backend;
  final bool isOffline;

  bool get isConfigured => backend != AskBackendMode.unconfigured;

  bool get canUseAsk => isConfigured && !isOffline;

  bool get isByok => backend == AskBackendMode.byok;

  bool get canWrappedNarrative => canUseAsk;

  bool get canPlayerInsights => canUseAsk;
}
