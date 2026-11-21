import {
  ACTION_MAX_TOKENS,
  ALLOWED_ACTIONS,
  ALLOWED_CHAT_TOOL_NAMES,
  buildSystemPrompt,
  sanitizeLocale,
  type AskAction,
} from "./prompts";
import { checkAndConsumeQuota, readQuota, type QuotaEnv } from "./quota";

export interface SecretsStoreSecret {
  get(): Promise<string>;
}

export interface Env extends QuotaEnv {
  DEEPSEEK_API_KEY?: string | SecretsStoreSecret;
  DEEPSEEK_MODEL?: string;
}

async function resolveDeepSeekApiKey(env: Env): Promise<string> {
  const raw = env.DEEPSEEK_API_KEY;
  if (!raw) return "";
  if (typeof raw === "string") return raw.trim();
  if (typeof raw === "object" && typeof raw.get === "function") {
    try {
      const value = await raw.get();
      return typeof value === "string" ? value.trim() : "";
    } catch {
      return "";
    }
  }
  return "";
}

const DEEPSEEK_API_URL = "https://api.deepseek.com/chat/completions";
const MAX_BODY_BYTES = 65_536;
const INSTALL_ID_RE = /^[a-zA-Z0-9_-]{8,64}$/;
const TURN_ID_RE = /^[a-zA-Z0-9_-]{6,64}$/;

interface ClientToolDef {
  type?: unknown;
  function?: {
    name?: unknown;
    description?: unknown;
    parameters?: unknown;
  };
}

interface AskRequestBody {
  action?: unknown;
  locale?: unknown;
  messages?: unknown;
  tools?: unknown;
  enableWebSearch?: unknown;
  jsonMode?: unknown;
  stream?: unknown;
  maxOutputTokens?: unknown;
  turnId?: unknown;
}

function jsonResponse(
  data: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {}
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

function quotaHeaders(q: {
  remaining: number;
  limit: number;
  resetAt: string;
}): Record<string, string> {
  return {
    "X-Ask-Quota-Remaining": String(q.remaining),
    "X-Ask-Quota-Limit": String(q.limit),
    "X-Ask-Quota-Reset": q.resetAt,
  };
}

function sanitizeMessages(raw: unknown): Record<string, unknown>[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 24) {
    return null;
  }
  const out: Record<string, unknown>[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") return null;
    const msg = item as Record<string, unknown>;
    const role = typeof msg.role === "string" ? msg.role : "";
    // Strip client-supplied system roles; server owns system instructions.
    if (role === "system") continue;
    if (role !== "user" && role !== "assistant" && role !== "tool") return null;

    const clean: Record<string, unknown> = { role };
    if (typeof msg.content === "string") {
      clean.content = msg.content.slice(0, 12_000);
    } else if (msg.content === null) {
      clean.content = null;
    }
    if (role === "assistant" && Array.isArray(msg.tool_calls)) {
      clean.tool_calls = msg.tool_calls.slice(0, 16);
    }
    if (role === "assistant" && Array.isArray(msg.server_tool_calls)) {
      clean.server_tool_calls = msg.server_tool_calls.slice(0, 16);
    }
    if (role === "tool") {
      if (typeof msg.tool_call_id !== "string" || !msg.tool_call_id) return null;
      clean.tool_call_id = msg.tool_call_id;
      if (typeof msg.name === "string" && msg.name) {
        clean.name = msg.name;
      }
    }
    out.push(clean);
  }
  return out.length > 0 ? out : null;
}

function buildTools(
  action: AskAction,
  rawTools: unknown,
  enableWebSearch: boolean
): unknown[] | undefined {
  const out: unknown[] = [];

  if (action === "chat" && Array.isArray(rawTools)) {
    for (const t of rawTools) {
      const def = t as ClientToolDef;
      if (def?.type !== "function" || !def.function) continue;
      const name = typeof def.function.name === "string" ? def.function.name : "";
      if (!ALLOWED_CHAT_TOOL_NAMES.has(name)) continue;
      out.push({
        type: "function",
        function: {
          name,
          description:
            typeof def.function.description === "string"
              ? def.function.description.slice(0, 500)
              : "",
          parameters: def.function.parameters ?? { type: "object", properties: {} },
        },
      });
    }
  }

  if (action === "track_insights" || (action === "chat" && enableWebSearch)) {
    out.push({
      type: "deepseek_web_search",
      name: "deepseek_web_search",
    });
  }

  return out.length > 0 ? out : undefined;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        const apiKey = await resolveDeepSeekApiKey(env);
        return jsonResponse({
          ok: true,
          model: env.DEEPSEEK_MODEL || "deepseek-flash",
          hasApiKey: Boolean(apiKey),
        });
      }

      const installId = (request.headers.get("X-Sonora-Install-Id") || "").trim();
      if (!INSTALL_ID_RE.test(installId)) {
        return jsonResponse({ error: "invalid_install_id" }, 400);
      }

      if (request.method === "GET" && url.pathname === "/v1/quota") {
        const [quota, apiKey] = await Promise.all([
          readQuota(env, installId),
          resolveDeepSeekApiKey(env),
        ]);
        return jsonResponse(
          {
            ...quota,
            configured: Boolean(apiKey),
          },
          200,
          quotaHeaders(quota)
        );
      }

      if (request.method !== "POST" || url.pathname !== "/v1/ask") {
        return jsonResponse({ error: "not_found" }, 404);
      }

      const apiKey = await resolveDeepSeekApiKey(env);
      if (!apiKey) {
        return jsonResponse({ error: "proxy_not_configured" }, 503);
      }

      const contentLength = Number.parseInt(
        request.headers.get("content-length") || "0",
        10
      );
      if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
        return jsonResponse({ error: "payload_too_large" }, 413);
      }

      let body: AskRequestBody;
      try {
        const rawText = await request.text();
        if (rawText.length > MAX_BODY_BYTES) {
          return jsonResponse({ error: "payload_too_large" }, 413);
        }
        body = JSON.parse(rawText) as AskRequestBody;
      } catch {
        return jsonResponse({ error: "invalid_json" }, 400);
      }

      const actionRaw = typeof body.action === "string" ? body.action.trim() : "";
      if (!ALLOWED_ACTIONS.has(actionRaw)) {
        return jsonResponse({ error: "invalid_action" }, 400);
      }
      const action = actionRaw as AskAction;
      const locale = sanitizeLocale(body.locale);
      const clientMessages = sanitizeMessages(body.messages);
      if (!clientMessages) {
        return jsonResponse({ error: "invalid_messages" }, 400);
      }

      const rawTurnId = typeof body.turnId === "string" ? body.turnId.trim() : "";
      const turnId = TURN_ID_RE.test(rawTurnId) ? rawTurnId : undefined;
      const ip =
        request.headers.get("CF-Connecting-IP") ||
        request.headers.get("X-Forwarded-For") ||
        "0.0.0.0";

      const quota = await checkAndConsumeQuota(env, {
        installId,
        ip,
        action,
        turnId,
      });
      if (!quota.allowed) {
        return jsonResponse(
          {
            error: quota.reason || "quota_exceeded",
            remaining: quota.remaining,
            limit: quota.limit,
            resetAt: quota.resetAt,
          },
          quota.status,
          quotaHeaders(quota)
        );
      }

      const capTokens = ACTION_MAX_TOKENS[action];
      const requestedTokens =
        typeof body.maxOutputTokens === "number" &&
        Number.isFinite(body.maxOutputTokens) &&
        body.maxOutputTokens > 0
          ? Math.min(Math.trunc(body.maxOutputTokens), capTokens)
          : capTokens;

      const stream = action === "chat" && body.stream === true;
      const enableWebSearch = body.enableWebSearch === true;
      const tools = buildTools(action, body.tools, enableWebSearch);

      // DeepSeek API: do not combine response_format json_object with tools (e.g. deepseek_web_search).
      const forceJson = action !== "chat" && !tools;

      const deepseekPayload: Record<string, unknown> = {
        model: env.DEEPSEEK_MODEL || "deepseek-flash",
        messages: [
          { role: "system", content: buildSystemPrompt(action, locale) },
          ...clientMessages,
        ],
        thinking: { type: "disabled" },
        max_tokens: requestedTokens,
        temperature: action === "chat" || action === "wrapped" || action === "pulse_drop" ? 0.5 : 0.2,
        stream,
      };

      if (tools) {
        deepseekPayload.tools = tools;
      }
      if (forceJson) {
        deepseekPayload.response_format = { type: "json_object" };
      }

      const upstream = await fetch(DEEPSEEK_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(deepseekPayload),
      });

      const responseHeaders = new Headers({
        "Content-Type":
          upstream.headers.get("Content-Type") ||
          (stream ? "text/event-stream; charset=utf-8" : "application/json; charset=utf-8"),
        "Cache-Control": "no-store",
        ...quotaHeaders(quota),
      });

      // Stream upstream body directly to keep Worker memory minimal.
      return new Response(upstream.body, {
        status: upstream.status,
        headers: responseHeaders,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(
        JSON.stringify({
          message: "sonora_ask_proxy_error",
          error: message,
        })
      );
      return jsonResponse({ error: "internal_error" }, 500);
    }
  },
};
