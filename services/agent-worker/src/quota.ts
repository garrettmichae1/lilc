/**
 * 10k users, two 12-hour windows, shared free APIs.
 * Groq ~14k req/day + Gemini ~1.5k + OpenRouter free ~0.05–1k ≈ ~16–18k req/day.
 * 10_000 users × 1 request × 2 windows = 20_000, so we cap globally and give
 * each person 1 request / ~4k tokens per 12 hours. Active users get a turn;
 * if everyone hammers at once, the global cap protects the pool.
 */
export function windowId(env: { WINDOW_HOURS: string }): string {
  const hours = Number(env.WINDOW_HOURS || 12);
  return String(Math.floor(Date.now() / (hours * 3600_000)));
}

export function budgets(env: {
  EXPECTED_USERS: string;
  GLOBAL_REQUESTS_PER_DAY: string;
  TOKENS_PER_WINDOW: string;
  WINDOW_HOURS: string;
}) {
  const users = Math.max(1, Number(env.EXPECTED_USERS || 10000));
  const globalDay = Math.max(1, Number(env.GLOBAL_REQUESTS_PER_DAY || 18000));
  const windows = 24 / Math.max(1, Number(env.WINDOW_HOURS || 12));
  const perUserRequests = Math.max(1, Math.floor(globalDay / users / windows));
  const tokens = Math.max(1000, Number(env.TOKENS_PER_WINDOW || 4000));
  return { perUserRequests, tokens, globalDay, users };
}

export function estimateTokens(body: unknown): number {
  const bytes = new TextEncoder().encode(JSON.stringify(body)).length;
  return Math.ceil(bytes / 4) + 400;
}

export async function readUsage(key: string): Promise<{ requests: number; tokens: number }> {
  const hit = await caches.default.match(new Request(`https://lilc.quota/${key}`));
  if (!hit) return { requests: 0, tokens: 0 };
  return (await hit.json()) as { requests: number; tokens: number };
}

export async function writeUsage(key: string, usage: { requests: number; tokens: number }): Promise<void> {
  await caches.default.put(
    new Request(`https://lilc.quota/${key}`),
    new Response(JSON.stringify(usage), { headers: { "Cache-Control": "max-age=50000" } })
  );
}

export async function readGlobal(day: string): Promise<number> {
  const hit = await caches.default.match(new Request(`https://lilc.quota/global/${day}`));
  return hit ? Number(await hit.text()) : 0;
}

export async function writeGlobal(day: string, count: number): Promise<void> {
  await caches.default.put(
    new Request(`https://lilc.quota/global/${day}`),
    new Response(String(count), { headers: { "Cache-Control": "max-age=90000" } })
  );
}

export function utcDay(): string {
  return new Date().toISOString().slice(0, 10);
}
