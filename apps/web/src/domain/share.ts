import { lessonById, type FirstHourLesson } from "./curriculum";

export type SharePayload =
  | { kind: "lesson"; id: string }
  | { kind: "source"; fileName: string; code: string };

const VERSION = 1;

/** Short lesson link: `#l=hello`. Custom program: `#c=` + base64url JSON. */
export function encodeShareHash(payload: SharePayload): string {
  if (payload.kind === "lesson") {
    return `#l=${encodeURIComponent(payload.id)}`;
  }
  const json = JSON.stringify({
    v: VERSION,
    n: payload.fileName,
    s: payload.code,
  });
  return `#c=${bytesToBase64Url(utf8Bytes(json))}`;
}

export function parseShareHash(hash: string): SharePayload | undefined {
  const raw = hash.startsWith("#") ? hash.slice(1) : hash;
  if (raw.length === 0) {
    return undefined;
  }
  const query = raw.startsWith("?") ? raw.slice(1) : raw;
  const params = new URLSearchParams(query.includes("=") ? query.replace(/^#/, "") : `l=${query}`);
  const lessonId = params.get("l") ?? params.get("lesson");
  if (lessonId && lessonById(lessonId)) {
    return { kind: "lesson", id: lessonId };
  }
  const compact = params.get("c");
  if (compact) {
    try {
      const parsed = JSON.parse(utf8String(base64UrlToBytes(compact))) as {
        v?: number;
        n?: string;
        s?: string;
        l?: string;
      };
      if (typeof parsed.l === "string" && lessonById(parsed.l)) {
        return { kind: "lesson", id: parsed.l };
      }
      if (typeof parsed.s === "string") {
        return {
          kind: "source",
          fileName: sanitizeFileName(parsed.n),
          code: parsed.s,
        };
      }
    } catch {
      return undefined;
    }
  }
  return undefined;
}

export function lessonFromPayload(payload: SharePayload): FirstHourLesson | undefined {
  return payload.kind === "lesson" ? lessonById(payload.id) : undefined;
}

export function playgroundURL(payload: SharePayload, origin = "https://garrettmichae1.github.io/lilc/web/"): string {
  const base = origin.endsWith("/") ? origin : `${origin}/`;
  return `${base}${encodeShareHash(payload)}`;
}

function sanitizeFileName(name: string | undefined): string {
  const trimmed = (name ?? "shared.c").trim();
  const safe = Array.from(trimmed)
    .map((character) => (/[A-Za-z0-9._-]/.test(character) ? character : "-"))
    .join("");
  const fallback = safe.length === 0 ? "shared.c" : safe;
  return fallback.toLowerCase().endsWith(".c") ? fallback : `${fallback}.c`;
}

function utf8Bytes(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

function utf8String(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  const base64 = btoa(binary);
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlToBytes(text: string): Uint8Array {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  const base64 = padded + pad;
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}
