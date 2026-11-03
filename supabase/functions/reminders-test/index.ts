import { caller, deviceToken, handle, json, readJson, sb } from "../_shared/common.ts";
import {
  type Account,
  deliver,
  deliverAccount,
  type Device,
  type Reminder,
} from "../_shared/notify.ts";

Deno.serve(handle(async (req) => {
  const who = await caller(req);
  if (who.kind === "invalid") return json({ error: "invalid_jwt" }, 401);
  const token = deviceToken(req);
  if (who.kind === "none" && !token) return json({ error: "bad_device" }, 401);
  const { reminderId } = await readJson(req);
  if (typeof reminderId !== "string") return json({ error: "bad_request" }, 400);

  if (who.kind === "user") {
    const { data } = await sb.from("reminders").select("*, account:reminder_accounts(*)")
      .eq("user_id", who.uid).eq("id", reminderId).maybeSingle();
    if (!data) return json({ error: "not_found" }, 404);
    const { account, ...r } = data as Reminder & { account: Account };
    const { data: devices } = await sb.from("reminder_devices").select("*")
      .eq("user_id", who.uid).not("push_subscription", "is", null);
    try {
      return json({ ok: true, channel: await deliverAccount(account, (devices ?? []) as Device[], r) });
    } catch (e) {
      return json({ ok: false, error: (e as Error).message }, 502);
    }
  }

  const { data } = await sb.from("reminders").select("*, device:reminder_devices(*)")
    .eq("device_token", token).eq("id", reminderId).maybeSingle();
  if (!data) return json({ error: "not_found" }, 404);

  const { device, ...r } = data as Reminder & { device: Device };
  try {
    return json({ ok: true, channel: await deliver(device, r) });
  } catch (e) {
    return json({ ok: false, error: (e as Error).message }, 502);
  }
}));
