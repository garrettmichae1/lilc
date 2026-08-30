import type { Env } from "./types";

export async function proxyChatCompletions(env: Env, body: unknown): Promise<Response> {
  const base = env.OPENAI_BASE_URL.replace(/\/$/, "");
  const upstream = `${base}/chat/completions`;

  const payload = asRecord(body);
  payload.model = env.OPENAI_MODEL;
  payload.tool_choice = payload.tool_choice ?? "auto";

  const response = await fetch(upstream, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    return json({ error: "upstream_failed" }, 502);
  }
  return new Response(response.body, {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function asRecord(body: unknown): Record<string, unknown> {
  if (typeof body === "object" && body !== null && !Array.isArray(body)) {
    return { ...(body as Record<string, unknown>) };
  }
  return {};
}

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
