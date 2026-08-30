export interface Env {
  OPENAI_API_KEY?: string;
  GROQ_API_KEY?: string;
  GOOGLE_API_KEY?: string;
  OPENROUTER_API_KEY?: string;
  AGENT_DEBUG_SECRET?: string;
  GITHUB_CLIENT_ID?: string;
  GITHUB_CLIENT_SECRET?: string;
  GITHUB_MODEL?: string;
  APPLE_BUNDLE_ID: string;
  PRODUCT_ID: string;
  OPENAI_MODEL: string;
  OPENAI_BASE_URL: string;
  MAX_BODY_BYTES: string;
  RATE_LIMIT_PER_MINUTE: string;
  EXPECTED_USERS: string;
  GLOBAL_REQUESTS_PER_DAY: string;
  WINDOW_HOURS: string;
  TOKENS_PER_WINDOW: string;
}

export interface Identity {
  id: string;
  source: "storekit" | "debug" | "device" | "github";
  githubToken?: string;
}
