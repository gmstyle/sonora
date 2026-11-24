import { buildSystemPrompt } from "./prompts";
import { readWeeklyDropsQuota, type QuotaEnv } from "./quota";

export interface PulseEnv extends QuotaEnv {
  AI?: Ai;
  WORKERS_AI_DROP_MODEL?: string;
  AI_GATEWAY_ID?: string;
  PULSE_COOLDOWN_HOURS?: string;
  PULSE_QUIET_START?: string;
  PULSE_QUIET_END?: string;
}

export const DEFAULT_WORKERS_AI_DROP_MODEL =
  "@cf/meta/llama-3.3-70b-instruct-fp8-fast";

export const DEFAULT_ENABLED_TRIGGERS: readonly string[] = [
  "new_release",
  "new_podcast_episode",
  "comeback_mix",
  "weekly_recap",
  "editorial_pulse",
  "forgotten_favorites",
  "heavy_rotation",
  "taste_discovery",
];

const EDITORIAL_TTL_SECONDS = 604_800;

export const PULSE_DROP_JSON_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    body: { type: "string" },
    starterPrompt: { type: "string" },
  },
  required: ["title", "body", "starterPrompt"],
  additionalProperties: false,
};

export const EDITORIAL_PULSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    theme: { type: "string" },
    hook: { type: "string" },
    moodKeywords: {
      type: "array",
      items: { type: "string" },
    },
    promptAngle: { type: "string" },
  },
  required: ["theme", "hook", "moodKeywords", "promptAngle"],
  additionalProperties: false,
};

export interface EditorialPulseRecord {
  id: string;
  theme: string;
  hook: string;
  moodKeywords: string[];
  promptAngle: string;
  generatedAt: string;
}

export interface PulseConfigResponse {
  enabled: boolean;
  cooldownHours: number;
  quietHoursStart: number;
  quietHoursEnd: number;
  weeklyRemaining: number;
  weeklyLimit: number;
  enabledTriggers: string[];
  editorialPulse: EditorialPulseRecord | null;
}

function parseIntOrFallback(
  raw: unknown,
  fallback: number,
  min: number,
  max: number
): number {
  const parsed =
    typeof raw === "number"
      ? raw
      : typeof raw === "string"
        ? Number.parseInt(raw, 10)
        : Number.NaN;
  if (!Number.isFinite(parsed)) return fallback;
  const truncated = Math.trunc(parsed);
  return truncated >= min && truncated <= max ? truncated : fallback;
}

function isoWeekKey(now: Date): string {
  const d = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
  );
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(
    ((d.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7
  );
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

function utcDayStamp(now: Date): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export async function readPulseConfig(
  env: PulseEnv,
  installId: string,
  locale: string
): Promise<PulseConfigResponse> {
  const [rawOverride, rawEditorial, weekly] = await Promise.all([
    env.QUOTA_KV.get("pulse:config"),
    env.QUOTA_KV.get(`pulse:editorial:${locale}`),
    readWeeklyDropsQuota(env, installId),
  ]);

  let override: Record<string, unknown> = {};
  if (rawOverride) {
    try {
      const parsed = JSON.parse(rawOverride);
      if (parsed && typeof parsed === "object") {
        override = parsed as Record<string, unknown>;
      }
    } catch {
      override = {};
    }
  }

  let editorialPulse: EditorialPulseRecord | null = null;
  if (rawEditorial) {
    try {
      const parsed = JSON.parse(rawEditorial);
      if (parsed && typeof parsed === "object") {
        const rec = parsed as Record<string, unknown>;
        if (
          typeof rec.id === "string" &&
          typeof rec.theme === "string" &&
          typeof rec.hook === "string"
        ) {
          editorialPulse = {
            id: rec.id,
            theme: rec.theme,
            hook: rec.hook,
            moodKeywords: Array.isArray(rec.moodKeywords)
              ? rec.moodKeywords.filter((v): v is string => typeof v === "string")
              : [],
            promptAngle:
              typeof rec.promptAngle === "string" ? rec.promptAngle : "",
            generatedAt:
              typeof rec.generatedAt === "string" ? rec.generatedAt : "",
          };
        }
      }
    } catch {
      editorialPulse = null;
    }
  }

  const enabled =
    typeof override.enabled === "boolean" ? override.enabled : true;
  const cooldownHours = parseIntOrFallback(
    override.cooldownHours ?? env.PULSE_COOLDOWN_HOURS,
    48,
    1,
    336
  );
  const quietHoursStart = parseIntOrFallback(
    override.quietHoursStart ?? env.PULSE_QUIET_START,
    22,
    0,
    23
  );
  const quietHoursEnd = parseIntOrFallback(
    override.quietHoursEnd ?? env.PULSE_QUIET_END,
    9,
    0,
    23
  );

  let enabledTriggers = [...DEFAULT_ENABLED_TRIGGERS];
  if (Array.isArray(override.enabledTriggers)) {
    const allowed = new Set(DEFAULT_ENABLED_TRIGGERS);
    const filtered = override.enabledTriggers.filter(
      (t): t is string => typeof t === "string" && allowed.has(t)
    );
    enabledTriggers = filtered;
  }

  return {
    enabled,
    cooldownHours,
    quietHoursStart,
    quietHoursEnd,
    weeklyRemaining: weekly.remaining,
    weeklyLimit: weekly.limit,
    enabledTriggers,
    editorialPulse,
  };
}

function extractWorkersAiJsonObject(result: unknown): Record<string, unknown> | null {
  if (!result || typeof result !== "object") return null;
  const obj = result as Record<string, unknown>;
  const rawCandidate =
    obj.response ??
    (Array.isArray(obj.choices) && obj.choices[0] && typeof obj.choices[0] === "object"
      ? (obj.choices[0] as { message?: { content?: unknown } }).message?.content
      : undefined);

  if (rawCandidate && typeof rawCandidate === "object") {
    return rawCandidate as Record<string, unknown>;
  }
  if (typeof rawCandidate === "string") {
    const trimmed = rawCandidate.trim();
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        const parsed = JSON.parse(trimmed.slice(start, end + 1));
        if (parsed && typeof parsed === "object") {
          return parsed as Record<string, unknown>;
        }
      } catch {
        return null;
      }
    }
  }
  return null;
}

export async function runWorkersAiPulseDrop(
  env: PulseEnv,
  locale: string,
  clientMessages: Record<string, unknown>[]
): Promise<string | null> {
  if (!env.AI) return null;

  const model =
    (env.WORKERS_AI_DROP_MODEL || "").trim() || DEFAULT_WORKERS_AI_DROP_MODEL;
  const gatewayId = (env.AI_GATEWAY_ID || "").trim();

  const messages = [
    { role: "system", content: buildSystemPrompt("pulse_drop", locale) },
    ...clientMessages.map((m) => ({
      role: typeof m.role === "string" ? m.role : "user",
      content: typeof m.content === "string" ? m.content : "",
    })),
  ];

  try {
    const result = await env.AI.run(
      model as keyof AiModels,
      {
        messages,
        max_tokens: 220,
        temperature: 0.6,
        response_format: {
          type: "json_schema",
          json_schema: PULSE_DROP_JSON_SCHEMA,
        },
      } as AiTextGenerationInput,
      gatewayId
        ? {
            gateway: {
              id: gatewayId,
              metadata: { action: "pulse_drop", locale },
            },
          }
        : undefined
    );

    const parsed = extractWorkersAiJsonObject(result);
    if (!parsed) return null;
    const title = typeof parsed.title === "string" ? parsed.title.trim() : "";
    const body = typeof parsed.body === "string" ? parsed.body.trim() : "";
    const starterPrompt =
      typeof parsed.starterPrompt === "string" ? parsed.starterPrompt.trim() : "";
    if (!title || !body || !starterPrompt) return null;

    return JSON.stringify({
      title: title.slice(0, 60),
      body: body.slice(0, 150),
      starterPrompt: starterPrompt.slice(0, 130),
    });
  } catch (error) {
    console.warn(
      JSON.stringify({
        message: "workers_ai_pulse_drop_failed",
        error: error instanceof Error ? error.message : String(error),
      })
    );
    return null;
  }
}

export async function refreshEditorialPulses(
  env: PulseEnv,
  now = new Date()
): Promise<void> {
  if (!env.AI) return;
  const model =
    (env.WORKERS_AI_DROP_MODEL || "").trim() || DEFAULT_WORKERS_AI_DROP_MODEL;
  const gatewayId = (env.AI_GATEWAY_ID || "").trim();
  const week = isoWeekKey(now);
  const day = utcDayStamp(now);
  const weekday = now.toLocaleDateString("en-US", {
    weekday: "long",
    timeZone: "UTC",
  });
  const month = now.toLocaleDateString("en-US", {
    month: "long",
    timeZone: "UTC",
  });

  for (const locale of ["en", "it"] as const) {
    try {
      const system = `You curate a tiny musical mood spark for Sonora Ask in language "${locale}". Reply ONLY with JSON matching the schema. Informal tone ('tu' in Italian). Never mention AI or models.`;
      const user = JSON.stringify({
        locale,
        weekday,
        month,
        hint:
          weekday === "Friday"
            ? "New Music Friday & weekend transition"
            : "Fresh week reset & sonic focus",
      });

      const result = await env.AI.run(
        model as keyof AiModels,
        {
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
          max_tokens: 180,
          temperature: 0.7,
          response_format: {
            type: "json_schema",
            json_schema: EDITORIAL_PULSE_JSON_SCHEMA,
          },
        } as AiTextGenerationInput,
        gatewayId
          ? {
              gateway: {
                id: gatewayId,
                metadata: { action: "editorial_cron", locale },
              },
            }
          : undefined
      );

      const parsed = extractWorkersAiJsonObject(result);
      if (!parsed) continue;
      const theme = typeof parsed.theme === "string" ? parsed.theme.trim() : "";
      const hook = typeof parsed.hook === "string" ? parsed.hook.trim() : "";
      const promptAngle =
        typeof parsed.promptAngle === "string" ? parsed.promptAngle.trim() : "";
      const moodKeywords = Array.isArray(parsed.moodKeywords)
        ? parsed.moodKeywords
            .filter((k): k is string => typeof k === "string" && k.trim().length > 0)
            .slice(0, 4)
        : [];
      if (!theme || !hook) continue;

      const record: EditorialPulseRecord = {
        id: `editorial:${week}:${day}:${locale}`,
        theme: theme.slice(0, 60),
        hook: hook.slice(0, 120),
        moodKeywords,
        promptAngle: promptAngle.slice(0, 100),
        generatedAt: now.toISOString(),
      };

      await env.QUOTA_KV.put(
        `pulse:editorial:${locale}`,
        JSON.stringify(record),
        { expirationTtl: EDITORIAL_TTL_SECONDS }
      );
    } catch (error) {
      console.warn(
        JSON.stringify({
          message: "editorial_cron_locale_failed",
          locale,
          error: error instanceof Error ? error.message : String(error),
        })
      );
    }
  }
}
