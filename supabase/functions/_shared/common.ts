import { createClient } from "npm:@supabase/supabase-js@2.45.4";

export const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type, x-reminder-device, apikey, authorization",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/** Wraps a POST handler with CORS preflight, method check and error catching. */
export function handle(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    try {
      return await fn(req);
    } catch (e) {
      console.error(e);
      return json({ error: "internal" }, 500);
    }
  };
}

/** Returns the device token from the header, or null when missing/malformed. */
export function deviceToken(req: Request): string | null {
  const t = req.headers.get("x-reminder-device") ?? "";
  return /^[a-f0-9]{64}$/.test(t) ? t : null;
}

export type Caller =
  | { kind: "none" }
  | { kind: "invalid" }
  | { kind: "user"; uid: string };

/** Role claim of a JWT-shaped string, read WITHOUT verifying it; null if not a JWT. */
function unverifiedRole(jwt: string): string | null {
  const parts = jwt.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "=")));
    return typeof claims?.role === "string" ? claims.role : null;
  } catch {
    return null;
  }
}

/**
 * Identifies the caller. A bearer that is not a JWT, or an anon/service-role
 * key, means "no account" (device mode, the anon key is also sent as apikey).
 * Any other bearer must be a valid user JWT, verified with auth.getUser; the
 * unverified role claim is only used to choose the path, never to trust a sub.
 */
export async function caller(req: Request): Promise<Caller> {
  const m = (req.headers.get("authorization") ?? "").match(/^Bearer\s+(\S+)$/i);
  if (!m) return { kind: "none" };
  const role = unverifiedRole(m[1]);
  if (role === null || role === "anon" || role === "service_role") return { kind: "none" };
  const { data, error } = await sb.auth.getUser(m[1]);
  if (error || !data.user) return { kind: "invalid" };
  return { kind: "user", uid: data.user.id };
}

/** Who owns the rows of a request: a device (local mode) or an account. */
export interface Owner {
  col: "device_token" | "user_id";
  val: string;
  /** Table holding timezone, quiet hours, email and Telegram settings. */
  table: "reminder_devices" | "reminder_accounts";
}

export const deviceOwner = (token: string): Owner =>
  ({ col: "device_token", val: token, table: "reminder_devices" });
export const accountOwner = (uid: string): Owner =>
  ({ col: "user_id", val: uid, table: "reminder_accounts" });

/** Creates the account settings row if it does not exist yet. */
export async function ensureAccount(uid: string): Promise<void> {
  const { error } = await sb
    .from("reminder_accounts")
    .upsert({ user_id: uid }, { onConflict: "user_id", ignoreDuplicates: true });
  if (error) throw error;
}

// deno-lint-ignore no-explicit-any
export type Obj = Record<string, any>;

export async function readJson(req: Request): Promise<Obj> {
  try {
    const v = await req.json();
    return v && typeof v === "object" ? v : {};
  } catch {
    return {};
  }
}

const secretCache = new Map<string, string>();

/** Reads a Vault secret through public.reminder_secret (cached per isolate). */
export async function secret(name: string): Promise<string> {
  const hit = secretCache.get(name);
  if (hit) return hit;
  const { data, error } = await sb.rpc("reminder_secret", { name });
  if (error || !data) throw new Error(`missing vault secret: ${name}`);
  secretCache.set(name, data as string);
  return data as string;
}

export async function sha256Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function randomHex(bytes: number): string {
  const a = crypto.getRandomValues(new Uint8Array(bytes));
  return [...a].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Creates the device row if it does not exist yet. */
export async function ensureDevice(token: string): Promise<void> {
  const { error } = await sb
    .from("reminder_devices")
    .upsert({ device_token: token }, { onConflict: "device_token", ignoreDuplicates: true });
  if (error) throw error;
}
