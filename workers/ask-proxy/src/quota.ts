import type { AskAction } from "./prompts";

export interface QuotaEnv {
  QUOTA_KV: KVNamespace;
  DAILY_DEVICE_LIMIT?: string;
  DAILY_IP_LIMIT?: string;
  DAILY_GLOBAL_LIMIT?: string;
  WEEKLY_DROPS_LIMIT?: string;
}

export interface QuotaResult {
  allowed: boolean;
  status: number;
  remaining: number;
  limit: number;
  resetAt: string;
  reason?: string;
}

const MAX_TURN_CONTINUATIONS = 8;
const DAY_TTL_SECONDS = 90_000;
const TURN_TTL_SECONDS = 600;
const WEEK_TTL_SECONDS = 691_200;

function parsePositiveInt(raw: string | undefined, fallback: number): number {
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function utcDayInfo(now = new Date()): { dayKey: string; resetAt: string } {
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const day = String(now.getUTCDate()).padStart(2, "0");
  const dayKey = `${year}-${month}-${day}`;
  const tomorrow = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1, 0, 0, 0)
  );
  return { dayKey, resetAt: tomorrow.toISOString() };
}

function isoWeekKey(now = new Date()): string {
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

async function sha256Hex(value: string): Promise<string> {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 24);
}

async function readInt(kv: KVNamespace, key: string): Promise<number> {
  const raw = await kv.get(key);
  if (!raw) return 0;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n >= 0 ? n : 0;
}

export async function readQuota(
  env: QuotaEnv,
  installId: string
): Promise<{ remaining: number; limit: number; resetAt: string }> {
  const limit = parsePositiveInt(env.DAILY_DEVICE_LIMIT, 30);
  const { dayKey, resetAt } = utcDayInfo();
  const used = await readInt(env.QUOTA_KV, `dev:${dayKey}:${installId}`);
  return {
    remaining: Math.max(0, limit - used),
    limit,
    resetAt,
  };
}

export async function checkAndConsumeQuota(
  env: QuotaEnv,
  params: {
    installId: string;
    ip: string;
    action: AskAction;
    turnId?: string;
  }
): Promise<QuotaResult> {
  const deviceLimit = parsePositiveInt(env.DAILY_DEVICE_LIMIT, 30);
  const ipLimit = parsePositiveInt(env.DAILY_IP_LIMIT, 90);
  const globalLimit = parsePositiveInt(env.DAILY_GLOBAL_LIMIT, 10_000);
  const weeklyDropsLimit = parsePositiveInt(env.WEEKLY_DROPS_LIMIT, 3);

  const { dayKey, resetAt } = utcDayInfo();
  const globalKey = `global:${dayKey}`;
  const devKey = `dev:${dayKey}:${params.installId}`;

  const globalUsed = await readInt(env.QUOTA_KV, globalKey);
  if (globalUsed >= globalLimit) {
    const devUsed = await readInt(env.QUOTA_KV, devKey);
    return {
      allowed: false,
      status: 503,
      remaining: Math.max(0, deviceLimit - devUsed),
      limit: deviceLimit,
      resetAt,
      reason: "global_cap_reached",
    };
  }

  // Pulse Drops do not consume the user's 30 daily credits; bounded per week.
  if (params.action === "pulse_drop") {
    const weekKey = isoWeekKey();
    const dropKey = `drops:${weekKey}:${params.installId}`;
    const [dropsUsed, devUsed] = await Promise.all([
      readInt(env.QUOTA_KV, dropKey),
      readInt(env.QUOTA_KV, devKey),
    ]);
    if (dropsUsed >= weeklyDropsLimit) {
      return {
        allowed: false,
        status: 429,
        remaining: Math.max(0, deviceLimit - devUsed),
        limit: deviceLimit,
        resetAt,
        reason: "weekly_drops_cap_reached",
      };
    }
    await Promise.all([
      env.QUOTA_KV.put(dropKey, String(dropsUsed + 1), {
        expirationTtl: WEEK_TTL_SECONDS,
      }),
      env.QUOTA_KV.put(globalKey, String(globalUsed + 1), {
        expirationTtl: DAY_TTL_SECONDS,
      }),
    ]);
    return {
      allowed: true,
      status: 200,
      remaining: Math.max(0, deviceLimit - devUsed),
      limit: deviceLimit,
      resetAt,
    };
  }

  // Tool-calling & batch continuations inside the same turnId share 1 credit.
  if (params.turnId) {
    const turnKey = `turn:${params.installId}:${params.turnId}`;
    const [turnCount, devUsed] = await Promise.all([
      readInt(env.QUOTA_KV, turnKey),
      readInt(env.QUOTA_KV, devKey),
    ]);
    if (turnCount > 0) {
      if (turnCount >= MAX_TURN_CONTINUATIONS) {
        return {
          allowed: false,
          status: 429,
          remaining: Math.max(0, deviceLimit - devUsed),
          limit: deviceLimit,
          resetAt,
          reason: "turn_continuation_limit",
        };
      }
      await Promise.all([
        env.QUOTA_KV.put(turnKey, String(turnCount + 1), {
          expirationTtl: TURN_TTL_SECONDS,
        }),
        env.QUOTA_KV.put(globalKey, String(globalUsed + 1), {
          expirationTtl: DAY_TTL_SECONDS,
        }),
      ]);
      return {
        allowed: true,
        status: 200,
        remaining: Math.max(0, deviceLimit - devUsed),
        limit: deviceLimit,
        resetAt,
      };
    }
  }

  const ipHash = await sha256Hex(params.ip);
  const ipKey = `ip:${dayKey}:${ipHash}`;
  const [devUsed, ipUsed] = await Promise.all([
    readInt(env.QUOTA_KV, devKey),
    readInt(env.QUOTA_KV, ipKey),
  ]);

  if (devUsed >= deviceLimit || ipUsed >= ipLimit) {
    return {
      allowed: false,
      status: 429,
      remaining: Math.max(0, deviceLimit - devUsed),
      limit: deviceLimit,
      resetAt,
      reason: devUsed >= deviceLimit ? "device_quota_exceeded" : "ip_quota_exceeded",
    };
  }

  const nextDevUsed = devUsed + 1;
  const writes: Promise<void>[] = [
    env.QUOTA_KV.put(devKey, String(nextDevUsed), { expirationTtl: DAY_TTL_SECONDS }),
    env.QUOTA_KV.put(ipKey, String(ipUsed + 1), { expirationTtl: DAY_TTL_SECONDS }),
    env.QUOTA_KV.put(globalKey, String(globalUsed + 1), {
      expirationTtl: DAY_TTL_SECONDS,
    }),
  ];
  if (params.turnId) {
    writes.push(
      env.QUOTA_KV.put(`turn:${params.installId}:${params.turnId}`, "1", {
        expirationTtl: TURN_TTL_SECONDS,
      })
    );
  }
  await Promise.all(writes);

  return {
    allowed: true,
    status: 200,
    remaining: Math.max(0, deviceLimit - nextDevUsed),
    limit: deviceLimit,
    resetAt,
  };
}
