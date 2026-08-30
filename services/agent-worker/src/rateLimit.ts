export async function enforceRateLimit(
  request: Request,
  subscriberId: string,
  perMinute: number
): Promise<boolean> {
  const minute = Math.floor(Date.now() / 60_000);
  const cache = caches.default;
  const key = new Request(`https://lilc.rate/${subscriberId}/${minute}`, { method: "GET" });
  const hit = await cache.match(key);
  const count = hit ? Number(await hit.text()) : 0;
  if (count >= perMinute) return false;
  const next = new Response(String(count + 1), {
    headers: { "Cache-Control": "max-age=90" },
  });
  await cache.put(key, next);
  return true;
}
