import { json, sb, secret } from "../_shared/common.ts";
import { sendTelegram } from "../_shared/notify.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (req.headers.get("x-telegram-bot-api-secret-token") !== (await secret("telegram_webhook_secret"))) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const update = await req.json();
    const text: unknown = update?.message?.text;
    const chatId: unknown = update?.message?.chat?.id;
    const m = typeof text === "string" ? text.match(/^\/start\s+([a-f0-9]{16})$/) : null;
    if (m && typeof chatId === "number") {
      // The code is a one-shot nonce: it belongs either to an account or to a device.
      const patch = { telegram_chat_id: chatId, telegram_link_code: null };
      const { data: acct } = await sb.from("reminder_accounts").update(patch)
        .eq("telegram_link_code", m[1]).select("user_id");
      let linked = !!acct?.length;
      if (!linked) {
        const { data } = await sb.from("reminder_devices").update(patch)
          .eq("telegram_link_code", m[1]).select("device_token");
        linked = !!data?.length;
      }
      if (linked) await sendTelegram(chatId, "Recordatorios vinculados");
    }
  } catch (e) {
    console.error(e);
  }
  // Always 200 so Telegram does not retry.
  return json({ ok: true });
});
