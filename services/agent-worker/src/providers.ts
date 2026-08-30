import { json } from "./openai";
import type { Env } from "./types";

interface Provider {
  name: string;
  url: string;
  key: string;
  model: string;
  extraHeaders?: Record<string, string>;
}

export function asRecord(body: unknown): Record<string, unknown> {
  if (typeof body === "object" && body !== null && !Array.isArray(body)) {
    return { ...(body as Record<string, unknown>) };
  }
  return {};
}

function githubProvider(env: Env, token: string): Provider {
  return {
    name: "github",
    url: "https://models.github.ai/inference/chat/completions",
    key: token,
    model: env.GITHUB_MODEL || "openai/gpt-4o-mini",
  };
}

function poolProviders(env: Env): Provider[] {
  const providers: Provider[] = [];
  if (env.GROQ_API_KEY) {
    providers.push({
      name: "groq",
      url: "https://api.groq.com/openai/v1/chat/completions",
      key: env.GROQ_API_KEY,
      model: "llama-3.3-70b-versatile",
    });
  }
  if (env.GOOGLE_API_KEY) {
    providers.push({
      name: "gemini",
      url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
      key: env.GOOGLE_API_KEY,
      model: "gemini-2.0-flash",
    });
  }
  if (env.OPENROUTER_API_KEY) {
    providers.push({
      name: "openrouter",
      url: "https://openrouter.ai/api/v1/chat/completions",
      key: env.OPENROUTER_API_KEY,
      model: "qwen/qwen3-coder:free",
      extraHeaders: {
        "HTTP-Referer": "https://lilc.app",
        "X-Title": "lilC",
      },
    });
  }
  if (env.OPENAI_API_KEY) {
    const base = (env.OPENAI_BASE_URL || "https://api.openai.com/v1").replace(/\/$/, "");
    providers.push({
      name: "openai",
      url: `${base}/chat/completions`,
      key: env.OPENAI_API_KEY,
      model: env.OPENAI_MODEL || "gpt-4o-mini",
    });
  }
  return providers;
}

async function tryProviders(providers: Provider[], body: unknown): Promise<Response | null> {
  const payload = asRecord(body);
  payload.tool_choice = payload.tool_choice ?? "auto";
  for (const provider of providers) {
    payload.model = provider.model;
    const response = await fetch(provider.url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${provider.key}`,
        "Content-Type": "application/json",
        ...provider.extraHeaders,
      },
      body: JSON.stringify(payload),
    });
    if (response.ok) {
      return new Response(response.body, {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "X-LilC-Provider": provider.name,
        },
      });
    }
  }
  return null;
}

/** GitHub Models first if the user signed in. Fake tokens fail here and do not skip the free-pool quota. */
export async function tryGitHubCompletion(
  env: Env,
  body: unknown,
  githubToken: string
): Promise<Response | null> {
  return tryProviders([githubProvider(env, githubToken)], body);
}

export async function routePoolCompletion(env: Env, body: unknown): Promise<Response> {
  const providers = poolProviders(env);
  if (providers.length === 0) {
    return json({ error: "not_configured" }, 503);
  }
  const hit = await tryProviders(providers, body);
  return hit ?? json({ error: "upstream_failed" }, 502);
}
