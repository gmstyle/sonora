/// On-device Ask model (Qwen3 0.6B dynamic INT4 LiteRT-LM).
///
/// Use the dynamic bundle — `qwen3_0_6b_mixed_int4.litertlm` loads but its
/// chat template fails at generate time (`string + sequence`, LiteRT INTERNAL
/// / code 13). Official fix: `Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm`
/// (flutter_edge_ai_litertlm #659 / LiteRT-LM #3865 family).
const kAskLlmHfRepo = 'litert-community/Qwen3-0.6B';
const kAskLlmFilename = 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';

/// Previous Ask artifact; uninstall when installing the supported bundle.
const kAskLlmLegacyFilename = 'qwen3_0_6b_mixed_int4.litertlm';

const kAskLlmDownloadUrl =
    'https://huggingface.co/$kAskLlmHfRepo/resolve/main/$kAskLlmFilename';

/// Approximate download size shown in Settings (~345 MB).
const kAskLlmApproxSizeMb = 345;

/// Default Gemini model id for Cloud Ask (Genkit `googleAI.gemini`).
const kAskGeminiModelId = 'gemini-flash-latest';

/// Soft timeout for a single Gemini completion.
const kAskGeminiTimeout = Duration(seconds: 45);
