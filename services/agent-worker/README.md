# lilC Agent worker

TypeScript on Cloudflare Workers. The iPhone app never holds Groq/Google/OpenRouter/OpenAI keys. This worker does.

## What we give 10k users

Shared free APIs are small. Config assumes ~18,000 pool requests per day and 10,000 people:

- **1 request and ~4,000 tokens per user per 12-hour window**
- **Global cap ~18,000 requests/day** so the pool is not emptied by a spike

That is about one agent turn per person per half-day when everyone is active. It is not unlimited chat.

Apple IAP (`lilc.agent.monthly`) skips the free-pool quota. GitHub Models is used only when a real GitHub token succeeds; a fake header does not skip quota.

## Secrets (not in git)

```bash
cd services/agent-worker
npx wrangler login
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put GOOGLE_API_KEY
npx wrangler secret put OPENROUTER_API_KEY
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put AGENT_DEBUG_SECRET
npx wrangler secret put GITHUB_CLIENT_ID
npx wrangler secret put GITHUB_CLIENT_SECRET
```

`.dev.vars` for local `wrangler dev`: same names.

GitHub OAuth callback must be registered as `https://<worker-host>/v1/auth/github/callback`. The app scheme is `lilc://github-oauth`.

GitHub Models typically needs a token that already has model access (Copilot / Models on that GitHub account). OAuth `read:user` is only for sign-in; if Models rejects the token, the worker falls back to the free pool and counts quota.

## Run

```bash
npm install
npx wrangler dev
npx wrangler deploy
```

## Contract

`POST /v1/chat/completions` — OpenAI chat-completions shape (messages + tools).

`GET /v1/quota` — current window usage.

Auth, one of:

- `X-LilC-Device` — anonymous free pool (required)
- `X-Apple-Transaction-JWS` — StoreKit extra-turns subscription
- `X-LilC-Debug` — matches `AGENT_DEBUG_SECRET`
- `X-LilC-GitHub` — user GitHub token for Models (optional)

The worker overwrites `model` per provider.

## iOS

Point `AgentRuntimeConfig.gatewayURL` at `https://<your-worker>.workers.dev/v1` or `https://api.lilc.app/v1`.

App Store: do not add buttons that send people to buy Copilot. Connecting an account they already have is allowed; selling Copilot in-app is not.
