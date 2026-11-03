import {
  accountOwner,
  caller,
  deviceOwner,
  deviceToken,
  ensureAccount,
  ensureDevice,
  handle,
  json,
  readJson,
  sb,
  secret,
  sha256Hex,
} from "../_shared/common.ts";

const MAX_ATTEMPTS = 5;
const TTL_MS = 10 * 60_000;

Deno.serve(handle(async (req) => {
  const who = await caller(req);
  if (who.kind === "invalid") return json({ error: "invalid_jwt" }, 401);
  const token = deviceToken(req);
  let owner;
  if (who.kind === "user") {
    owner = accountOwner(who.uid);
    await ensureAccount(who.uid);
  } else {
    if (!token) return json({ error: "bad_device" }, 401);
    owner = deviceOwner(token);
    await ensureDevice(token);
  }
  const body = await readJson(req);

  if (body.action === "request") {
    const email = typeof body.email === "string" ? body.email.trim() : "";
    if (!/^[^@\s]{1,64}@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) {
      return json({ error: "bad_email" }, 400);
    }
    // At most one code per minute per owner.
    const { data: prev } = await sb.from("email_codes").select("expires_at").eq(owner.col, owner.val).maybeSingle();
    if (prev && new Date(prev.expires_at).getTime() - Date.now() > TTL_MS - 60_000) {
      return json({ error: "too_soon" }, 429);
    }
    const n = new DataView(crypto.getRandomValues(new Uint8Array(4)).buffer).getUint32(0);
    const code = String(n % 1_000_000).padStart(6, "0");
    const { error } = await sb.from("email_codes").upsert({
      [owner.col]: owner.val,
      email,
      code_hash: await sha256Hex(`${owner.val}:${code}`),
      expires_at: new Date(Date.now() + TTL_MS).toISOString(),
      attempts: 0,
    }, { onConflict: owner.col });
    if (error) throw error;
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${await secret("resend_api_key")}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: await secret("resend_from"),
        to: email,
        subject: "Código de verificación",
        text: `Tu código de verificación es ${code}. Caduca en 10 minutos.`,
      }),
    });
    if (!res.ok) return json({ error: "email_send_failed" }, 502);
    return json({ ok: true });
  }

  if (body.action === "confirm") {
    const code = typeof body.code === "string" ? body.code.trim() : "";
    const { data: row } = await sb.from("email_codes").select("*").eq(owner.col, owner.val).maybeSingle();
    if (!row || new Date(row.expires_at).getTime() < Date.now()) return json({ error: "expired" }, 400);
    if (row.attempts >= MAX_ATTEMPTS) return json({ error: "too_many_attempts" }, 429);
    await sb.from("email_codes").update({ attempts: row.attempts + 1 }).eq(owner.col, owner.val);
    if (!/^\d{6}$/.test(code) || (await sha256Hex(`${owner.val}:${code}`)) !== row.code_hash) {
      return json({ error: "wrong_code" }, 400);
    }
    await sb.from(owner.table).update({ email: row.email, email_verified: true }).eq(owner.col, owner.val);
    await sb.from("email_codes").delete().eq(owner.col, owner.val);
    return json({ ok: true, email: row.email });
  }

  return json({ error: "bad_action" }, 400);
}));
