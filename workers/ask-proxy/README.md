# Sonora Ask Proxy (Cloudflare Worker)

Closed-action proxy between the Sonora Flutter client and DeepSeek / Workers AI, keeping `DEEPSEEK_API_KEY` in Cloudflare Secrets Store, observing traffic through **Cloudflare AI Gateway** (`sonora-ask-gateway`), enforcing per-device / per-IP / global quotas via `QUOTA_KV`, and powering proactive **Pulse Drops**.

## Endpoints

- `GET /health` — Health & configuration check (`hasApiKey`, `hasWorkersAi`, `aiGatewayId`, configured models).
- `GET /v1/quota` — Current daily quota remaining for `X-Sonora-Install-Id` (read-only, 0 credits).
- `GET /v1/pulse/config?locale=it|en` — Remote configuration, kill-switch, weekly Pulse Drop remaining quota (`WEEKLY_DROPS_LIMIT`), quiet hours, enabled triggers, and the Cron-generated `editorialPulse` from `QUOTA_KV`.
- `POST /v1/ask` — Validates `action` (`chat`, `mix_intent`, `search_intent`, `track_insights`, `lyrics_translate`, `wrapped`, `spotify_match`, `pulse_drop`), injects server-side system prompts, strips client `system` roles, and applies `QUOTA_KV` counters (`turnId` shares 1 credit across tool loops; `pulse_drop` uses the weekly drop allowance).
  - `pulse_drop` runs on **Workers AI** (`@cf/meta/llama-3.3-70b-instruct-fp8-fast` with JSON Schema) logged via AI Gateway, with automatic fallback to DeepSeek if Workers AI errors.
  - All other actions stream or complete via DeepSeek (`deepseek-flash`) routed through **Cloudflare AI Gateway**.

## Scheduled Cron Triggers

- Runs every Monday & Friday at `06:00 UTC` (`0 6 * * 1`, `0 6 * * 5`) via `scheduled()` to generate locale-specific (`en`, `it`) seasonal editorial sparks using Workers AI and cache them in `QUOTA_KV` under `pulse:editorial:<locale>` (TTL 7 days).

## Remote Kill-Switch / Config (`QUOTA_KV`)

Store an optional JSON value under key `pulse:config` in `QUOTA_KV` to tune or pause proactive drops without an app release:

```json
{
  "enabled": true,
  "cooldownHours": 48,
  "quietHoursStart": 22,
  "quietHoursEnd": 9,
  "enabledTriggers": [
    "new_release",
    "new_podcast_episode",
    "comeback_mix",
    "weekly_recap",
    "editorial_pulse",
    "forgotten_favorites",
    "heavy_rotation",
    "taste_discovery"
  ]
}
```

## Setup & Deploy

```bash
cd workers/ask-proxy
npm install
npm run typecheck
npx wrangler deploy
```
