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
      const { data } = await sb.from("reminder_devices")
        .update({ telegram_chat_id: chatId, telegram_link_code: null })
        .eq("telegram_link_code", m[1]).select("device_token");
      if (data?.length) await sendTelegram(chatId, "Recordatorios vinculados");
    }
  } catch (e) {
    console.error(e);
  }
  // Always 200 so Telegram does not retry.
  return json({ ok: true });
});
