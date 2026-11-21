/// Default DeepSeek V4.1 model id used by Ask across proxy and BYOK modes.
const kDeepSeekModelId = 'deepseek-flash';

/// Direct DeepSeek API base URL (OpenAI-compatible Chat Completions).
const kDeepSeekDirectBaseUrl = 'https://api.deepseek.com';

/// Proxy Ask base URL (overridable via `--dart-define=SONORA_ASK_PROXY_URL=...`
/// or in Settings).
const kAskProxyBaseUrl = String.fromEnvironment(
  'SONORA_ASK_PROXY_URL',
  defaultValue: 'https://sonora-ask-proxy.contattagmstyle.workers.dev',
);

/// Default daily Ask credit allowance per device on the managed proxy.
const kAskDailyCreditLimit = 30;

/// Soft timeout for a single DeepSeek or proxy completion round.
const kAskTimeout = Duration(seconds: 45);

/// Maximum tool-calling rounds executed within one Ask user turn.
const kAskMaxToolRounds = 6;

/// Maximum parallel tool calls executed in a single Ask round.
const kAskMaxToolCallsPerRound = 16;

/// Recent conversation message window sent to the model per turn.
const kAskHistoryWindowMessages = 8;

/// Maximum Spotify ambiguous/unmatched slots sent per batch request.
const kSpotifyAssistBatchSize = 12;

/// Target number of tracks suggested in an Ask Mix card.
const kAskMixTargetTrackCount = 20;
