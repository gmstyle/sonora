# Sonora Ask Proxy (Cloudflare Worker)

Closed-action proxy between the Sonora Flutter client and DeepSeek (`deepseek-flash`), keeping `DEEPSEEK_API_KEY` solely in Cloudflare Secrets and enforcing per-device, per-IP, and global rate limits via Cloudflare KV.

## Endpoints

- `GET /health` — Health & configuration check (`hasApiKey`, configured model).
- `GET /v1/quota` — Current daily quota remaining for `X-Sonora-Install-Id` (read-only, 0 credits).
- `POST /v1/ask` — Validates `action` (`chat`, `mix_intent`, `search_intent`, `track_insights`, `lyrics_translate`, `wrapped`, `spotify_match`, `pulse_drop`), injects server-side system prompts, strips client `system` roles, applies `QUOTA_KV` counters (`turnId` shares 1 credit across tool loops), and streams DeepSeek `chat/completions`.

## Setup Checklist

1. In the **Cloudflare Dashboard → Workers & Pages**, claim your `*.workers.dev` subdomain if you haven't yet.
2. Open the **`sonora-ask-proxy`** Worker → **Settings → Variables and Secrets** → add Secret `DEEPSEEK_API_KEY`.
3. Enable the `workers.dev` route for `sonora-ask-proxy` and configure the resulting URL in Sonora (`kAskProxyBaseUrl` or `--dart-define=SONORA_ASK_PROXY_URL=https://sonora-ask-proxy.<your-subdomain>.workers.dev`).

## Local Development / CLI Deploy

```bash
cd workers/ask-proxy
npm install
npx wrangler secret put DEEPSEEK_API_KEY
npx wrangler deploy
```
