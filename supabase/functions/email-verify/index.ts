import { deviceToken, ensureDevice, handle, json, readJson, sb, secret, sha256Hex } from "../_shared/common.ts";

const MAX_ATTEMPTS = 5;
const TTL_MS = 10 * 60_000;

Deno.serve(handle(async (req) => {
  const token = deviceToken(req);
  if (!token) return json({ error: "bad_device" }, 401);
  const body = await readJson(req);
  await ensureDevice(token);

  if (body.action === "request") {
    const email = typeof body.email === "string" ? body.email.trim() : "";
    if (!/^[^@\s]{1,64}@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) {
      return json({ error: "bad_email" }, 400);
    }
    // At most one code per minute per device.
    const { data: prev } = await sb.from("email_codes").select("expires_at").eq("device_token", token).maybeSingle();
    if (prev && new Date(prev.expires_at).getTime() - Date.now() > TTL_MS - 60_000) {
      return json({ error: "too_soon" }, 429);
    }
    const n = new DataView(crypto.getRandomValues(new Uint8Array(4)).buffer).getUint32(0);
    const code = String(n % 1_000_000).padStart(6, "0");
    const { error } = await sb.from("email_codes").upsert({
      device_token: token,
      email,
      code_hash: await sha256Hex(`${token}:${code}`),
      expires_at: new Date(Date.now() + TTL_MS).toISOString(),
      attempts: 0,
    });
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
    const { data: row } = await sb.from("email_codes").select("*").eq("device_token", token).maybeSingle();
    if (!row || new Date(row.expires_at).getTime() < Date.now()) return json({ error: "expired" }, 400);
    if (row.attempts >= MAX_ATTEMPTS) return json({ error: "too_many_attempts" }, 429);
    await sb.from("email_codes").update({ attempts: row.attempts + 1 }).eq("device_token", token);
    if (!/^\d{6}$/.test(code) || (await sha256Hex(`${token}:${code}`)) !== row.code_hash) {
      return json({ error: "wrong_code" }, 400);
    }
    await sb.from("reminder_devices").update({ email: row.email, email_verified: true })
      .eq("device_token", token);
    await sb.from("email_codes").delete().eq("device_token", token);
    return json({ ok: true, email: row.email });
  }

  return json({ error: "bad_action" }, 400);
}));
