import { deviceToken, handle, json, readJson, sb } from "../_shared/common.ts";
import { deliver, type Device, type Reminder } from "../_shared/notify.ts";

Deno.serve(handle(async (req) => {
  const token = deviceToken(req);
  if (!token) return json({ error: "bad_device" }, 401);
  const { reminderId } = await readJson(req);
  if (typeof reminderId !== "string") return json({ error: "bad_request" }, 400);

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
