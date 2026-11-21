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
const MAX_BODY_BYTES = 262_144;
const MAX_MESSAGES = 120;
const MAX_TOOL_CALLS_PER_MESSAGE = 48;
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
  toolChoice?: unknown;
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

function sanitizeToolCalls(rawToolCalls: unknown): Record<string, unknown>[] {
  if (!Array.isArray(rawToolCalls)) return [];
  const cleaned: Record<string, unknown>[] = [];
  const seenIds = new Set<string>();
  for (const item of rawToolCalls) {
    if (!item || typeof item !== "object") continue;
    const call = item as Record<string, unknown>;
    const id = typeof call.id === "string" ? call.id.trim() : "";
    if (!id || seenIds.has(id)) continue;
    const fn =
      call.function && typeof call.function === "object"
        ? (call.function as Record<string, unknown>)
        : null;
    if (!fn) continue;
    const name = typeof fn.name === "string" ? fn.name.trim() : "";
    if (!name) continue;
    const rawArgs = fn.arguments;
    const argsStr =
      typeof rawArgs === "string"
        ? rawArgs.slice(0, 12_000)
        : JSON.stringify(rawArgs ?? {}).slice(0, 12_000);
    seenIds.add(id);
    cleaned.push({
      id,
      type: "function",
      function: { name, arguments: argsStr },
    });
    if (cleaned.length >= MAX_TOOL_CALLS_PER_MESSAGE) break;
  }
  return cleaned;
}

function sanitizeMessages(raw: unknown): Record<string, unknown>[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_MESSAGES) {
    return null;
  }
  const out: Record<string, unknown>[] = [];
  const pendingToolCallIds = new Set<string>();
  let lastAssistantIndex = -1;

  function closePendingToolBlock(): void {
    if (lastAssistantIndex >= 0 && pendingToolCallIds.size > 0) {
      const parent = out[lastAssistantIndex];
      const existing = Array.isArray(parent.tool_calls)
        ? (parent.tool_calls as Record<string, unknown>[])
        : [];
      const answered = existing.filter(
        (c) => typeof c.id === "string" && !pendingToolCallIds.has(c.id)
      );
      if (answered.length > 0) {
        parent.tool_calls = answered;
      } else {
        delete parent.tool_calls;
        const hasContent =
          typeof parent.content === "string" && parent.content.length > 0;
        const hasServerCalls =
          Array.isArray(parent.server_tool_calls) &&
          parent.server_tool_calls.length > 0;
        if (!hasContent && !hasServerCalls) {
          out.splice(lastAssistantIndex, 1);
        }
      }
    }
    pendingToolCallIds.clear();
    lastAssistantIndex = -1;
  }

  for (const item of raw) {
    if (!item || typeof item !== "object") return null;
    const msg = item as Record<string, unknown>;
    const role = typeof msg.role === "string" ? msg.role : "";
    // Strip client-supplied system roles; server owns system instructions.
    if (role === "system") continue;
    if (role !== "user" && role !== "assistant" && role !== "tool") return null;

    if (role === "tool") {
      const toolCallId =
        typeof msg.tool_call_id === "string" ? msg.tool_call_id.trim() : "";
      if (!toolCallId) return null;
      if (!pendingToolCallIds.has(toolCallId)) {
        continue;
      }
      pendingToolCallIds.delete(toolCallId);
      const cleanTool: Record<string, unknown> = {
        role: "tool",
        tool_call_id: toolCallId,
        content:
          typeof msg.content === "string" ? msg.content.slice(0, 24_000) : "",
      };
      if (typeof msg.name === "string" && msg.name.trim()) {
        cleanTool.name = msg.name.trim();
      }
      out.push(cleanTool);
      continue;
    }

    closePendingToolBlock();

    const clean: Record<string, unknown> = { role };
    if (typeof msg.content === "string") {
      clean.content = msg.content.slice(0, 24_000);
    } else if (msg.content === null) {
      clean.content = null;
    }
    if (role === "assistant") {
      if (
        Array.isArray(msg.server_tool_calls) &&
        msg.server_tool_calls.length > 0
      ) {
        clean.server_tool_calls = msg.server_tool_calls.slice(0, 16);
      }
      const calls = sanitizeToolCalls(msg.tool_calls);
      if (calls.length > 0) {
        clean.tool_calls = calls;
        lastAssistantIndex = out.length;
        for (const call of calls) {
          pendingToolCallIds.add(call.id as string);
        }
      }
    }
    out.push(clean);
  }

  closePendingToolBlock();
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
        if (body.toolChoice === "none" || body.toolChoice === "auto") {
          deepseekPayload.tool_choice = body.toolChoice;
        }
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
