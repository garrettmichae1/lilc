import { identify, AuthError } from "./auth";
import { json } from "./openai";
import { routePoolCompletion, tryGitHubCompletion } from "./providers";
import {
  budgets,
  estimateTokens,
  readGlobal,
  readUsage,
  utcDay,
  windowId,
  writeGlobal,
  writeUsage,
} from "./quota";
import { handleGitHubAuth } from "./github";
import type { Env } from "./types";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, service: "lilc-agent" });
    }

    const oauth = await handleGitHubAuth(request, env, url);
    if (oauth) return oauth;

    if (request.method === "GET" && url.pathname === "/v1/quota") {
      try {
        const identity = await identify(request, env);
        return json(await quotaSnapshot(env, identity.id, Boolean(identity.githubToken)));
      } catch (error) {
        const status = error instanceof AuthError ? error.status : 401;
        return json({ error: error instanceof Error ? error.message : "Unauthorized" }, status);
      }
    }

    if (request.method !== "POST" || url.pathname !== "/v1/chat/completions") {
      return json({ error: "not_found" }, 404);
    }

    const maxBytes = Number(env.MAX_BODY_BYTES || 524288);
    const raw = await request.arrayBuffer();
    if (raw.byteLength > maxBytes) {
      return json({ error: "payload_too_large" }, 413);
    }

    let identity;
    try {
      identity = await identify(request, env);
    } catch (error) {
      const status = error instanceof AuthError ? error.status : 401;
      return json({ error: error instanceof Error ? error.message : "Unauthorized" }, status);
    }

    let body: unknown = {};
    try {
      body = JSON.parse(new TextDecoder().decode(raw));
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    if (identity.githubToken) {
      const github = await tryGitHubCompletion(env, body, identity.githubToken);
      if (github) return github;
    }

    const skipQuota = identity.source === "storekit" || identity.source === "debug";
    if (!skipQuota) {
      const gate = await consumeQuota(env, identity.id, estimateTokens(body));
      if (!gate.ok) {
        return json(
          {
            error: "quota_exceeded",
            message:
              "Free agent allowance is used until the next 12-hour window. Connect a GitHub account that already has Copilot or GitHub Models, or try later.",
            ...gate.snapshot,
          },
          429
        );
      }
    }

    return routePoolCompletion(env, body);
  },
} satisfies ExportedHandler<Env>;

async function quotaSnapshot(env: Env, userId: string, unlimited: boolean) {
  const win = windowId(env);
  const limits = budgets(env);
  const used = await readUsage(`${userId}:${win}`);
  const global = await readGlobal(utcDay());
  return {
    unlimited,
    windowHours: Number(env.WINDOW_HOURS || 12),
    requestsUsed: used.requests,
    requestsLimit: limits.perUserRequests,
    tokensUsed: used.tokens,
    tokensLimit: limits.tokens,
    globalRequestsToday: global,
    globalRequestsLimit: limits.globalDay,
  };
}

async function consumeQuota(env: Env, userId: string, tokens: number) {
  const snapshot = await quotaSnapshot(env, userId, false);
  const limits = budgets(env);
  if (snapshot.globalRequestsToday >= limits.globalDay) {
    return { ok: false, snapshot };
  }
  if (snapshot.requestsUsed >= limits.perUserRequests || snapshot.tokensUsed + tokens > limits.tokens) {
    return { ok: false, snapshot };
  }
  const win = windowId(env);
  await writeUsage(`${userId}:${win}`, {
    requests: snapshot.requestsUsed + 1,
    tokens: snapshot.tokensUsed + tokens,
  });
  await writeGlobal(utcDay(), snapshot.globalRequestsToday + 1);
  return { ok: true, snapshot };
}
