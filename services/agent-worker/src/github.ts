import type { Env } from "./types";
import { json } from "./openai";

export async function handleGitHubAuth(request: Request, env: Env, url: URL): Promise<Response | null> {
  if (!env.GITHUB_CLIENT_ID || !env.GITHUB_CLIENT_SECRET) return null;

  if (request.method === "GET" && url.pathname === "/v1/auth/github/start") {
    const callback = `${url.origin}/v1/auth/github/callback`;
    const authorize = new URL("https://github.com/login/oauth/authorize");
    authorize.searchParams.set("client_id", env.GITHUB_CLIENT_ID);
    authorize.searchParams.set("redirect_uri", callback);
    authorize.searchParams.set("scope", "read:user");
    return Response.redirect(authorize.toString(), 302);
  }

  if (request.method === "GET" && url.pathname === "/v1/auth/github/callback") {
    const code = url.searchParams.get("code");
    if (!code) return json({ error: "missing_code" }, 400);
    const tokenRes = await fetch("https://github.com/login/oauth/access_token", {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: env.GITHUB_CLIENT_ID,
        client_secret: env.GITHUB_CLIENT_SECRET,
        code,
      }),
    });
    const tokenJson = (await tokenRes.json()) as { access_token?: string };
    if (!tokenJson.access_token) return json({ error: "oauth_failed" }, 401);
    const app = new URL("lilc://github-oauth");
    app.searchParams.set("token", tokenJson.access_token);
    return Response.redirect(app.toString(), 302);
  }

  return null;
}
