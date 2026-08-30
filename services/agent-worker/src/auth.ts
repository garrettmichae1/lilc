import { compactVerify, decodeProtectedHeader, importX509 } from "jose";
import type { Env, Identity } from "./types";

interface AppleTransactionPayload {
  bundleId?: string;
  productId?: string;
  originalTransactionId?: string;
  expiresDate?: number;
  revocationDate?: number;
}

function pemFromX5C(b64: string): string {
  const body = b64.replace(/.{64}/g, "$&\n");
  return `-----BEGIN CERTIFICATE-----\n${body}\n-----END CERTIFICATE-----`;
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i += 1) {
    out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return out === 0;
}

export class AuthError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export async function identify(request: Request, env: Env): Promise<Identity> {
  const github = request.headers.get("X-LilC-GitHub")?.trim() ?? "";
  if (github) {
    return { id: `github:${github.slice(-12)}`, source: "github", githubToken: github };
  }

  const debug = request.headers.get("X-LilC-Debug") ?? "";
  if (env.AGENT_DEBUG_SECRET && debug && constantTimeEqual(debug, env.AGENT_DEBUG_SECRET)) {
    return { id: "debug", source: "debug" };
  }

  const jws = request.headers.get("X-Apple-Transaction-JWS") ?? "";
  if (jws.split(".").length === 3) {
    try {
      return await verifyStoreKit(jws, env);
    } catch {
      // fall through to device identity for the free pool
    }
  }

  const device = request.headers.get("X-LilC-Device")?.trim() ?? "";
  if (device.length >= 16 && device.length <= 80) {
    return { id: `device:${device}`, source: "device" };
  }

  throw new AuthError("Missing device id.", 401);
}

async function verifyStoreKit(jws: string, env: Env): Promise<Identity> {
  const header = decodeProtectedHeader(jws);
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || typeof x5c[0] !== "string") {
    throw new AuthError("Invalid App Store signature.", 401);
  }
  const key = await importX509(pemFromX5C(x5c[0]), "ES256");
  const verified = await compactVerify(jws, key);
  const payload = JSON.parse(new TextDecoder().decode(verified.payload)) as AppleTransactionPayload;
  if (payload.bundleId !== env.APPLE_BUNDLE_ID) throw new AuthError("Wrong app.", 403);
  if (payload.productId !== env.PRODUCT_ID) throw new AuthError("Wrong product.", 403);
  if (payload.revocationDate) throw new AuthError("Subscription was revoked.", 403);
  if (typeof payload.expiresDate === "number" && payload.expiresDate < Date.now()) {
    throw new AuthError("Subscription expired.", 403);
  }
  if (!payload.originalTransactionId) throw new AuthError("Invalid transaction.", 401);
  return { id: `iap:${payload.originalTransactionId}`, source: "storekit" };
}
