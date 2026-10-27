import { deviceToken, ensureDevice, handle, json, type Obj, randomHex, readJson, sb, secret } from "../_shared/common.ts";

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const MEALS = ["breakfast", "lunch", "snack", "dinner"];
const TYPES = ["weigh_in", "meal", "custom"];
const CHANNELS = ["push", "email", "telegram"];
const MAX_REMINDERS = 30;

function parseReminder(raw: Obj, device: string): Obj | null {
  const { id, type, mealType, label, time, days, channel } = raw;
  if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) return null;
  if (!TYPES.includes(type) || !CHANNELS.includes(channel)) return null;
  if (typeof time !== "string" || !TIME.test(time)) return null;
  if (!Array.isArray(days) || days.some((d) => !Number.isInteger(d) || d < 1 || d > 7)) return null;
  if ((type === "meal") !== MEALS.includes(mealType)) return null;
  return {
    device_token: device,
    id,
    type,
    meal_type: type === "meal" ? mealType : null,
    label: typeof label === "string" ? label.slice(0, 40) : "",
    time_local: time,
    days: [...new Set(days)],
    channel,
    enabled: raw.enabled !== false,
    skip_if_logged: raw.skipIfLogged === true,
  };
}

Deno.serve(handle(async (req) => {
  const token = deviceToken(req);
  if (!token) return json({ error: "bad_device" }, 401);
  const body = await readJson(req);
  await ensureDevice(token);

  // Meal flag: cheap call made right after the user logs a meal.
  const ml = body.mealLogged;
  if (ml) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(ml.date) || !MEALS.includes(ml.mealType)) {
      return json({ error: "bad_meal_flag" }, 400);
    }
    const { error } = await sb.from("meal_flags").upsert(
      { device_token: token, local_date: ml.date, meal_type: ml.mealType },
      { onConflict: "device_token,local_date,meal_type", ignoreDuplicates: true },
    );
    if (error) throw error;
  }

  // Device settings: only the keys present in the body are changed.
  const patch: Obj = { updated_at: new Date().toISOString() };
  if (body.timezone !== undefined) {
    try {
      new Intl.DateTimeFormat("en", { timeZone: body.timezone });
    } catch {
      return json({ error: "bad_timezone" }, 400);
    }
    patch.timezone = body.timezone;
  }
  for (const [key, col] of [["quietStart", "quiet_start"], ["quietEnd", "quiet_end"]]) {
    if (body[key] === undefined) continue;
    if (body[key] !== null && !TIME.test(body[key])) return json({ error: "bad_quiet_hours" }, 400);
    patch[col] = body[key];
  }
  if (body.pushSubscription !== undefined) {
    const s = body.pushSubscription;
    if (s !== null && (typeof s?.endpoint !== "string" || !s.endpoint.startsWith("https://"))) {
      return json({ error: "bad_subscription" }, 400);
    }
    patch.push_subscription = s;
    patch.push_failures = 0;
  }
  if (body.telegramLink === true) patch.telegram_link_code = randomHex(8);
  const { error: patchError } = await sb.from("reminder_devices").update(patch).eq("device_token", token);
  if (patchError) throw patchError;

  // Full replace of the reminders list.
  if (Array.isArray(body.reminders)) {
    if (body.reminders.length > MAX_REMINDERS) return json({ error: "too_many_reminders" }, 400);
    const rows = body.reminders.map((r: Obj) => parseReminder(r, token));
    if (rows.includes(null)) return json({ error: "bad_reminder" }, 400);
    const ids = rows.map((r: Obj) => r.id);
    let del = sb.from("reminders").delete().eq("device_token", token);
    if (ids.length) del = del.not("id", "in", `(${ids.join(",")})`);
    const { error: delError } = await del;
    if (delError) throw delError;
    if (rows.length) {
      // last_sent_at is not in the rows, so the upsert keeps it.
      const { error } = await sb.from("reminders").upsert(rows, { onConflict: "device_token,id" });
      if (error) throw error;
    }
  }

  const { data: d, error: dError } = await sb.from("reminder_devices").select("*")
    .eq("device_token", token).single();
  if (dError) throw dError;
  const { data: rs } = await sb.from("reminders").select("id, channel").eq("device_token", token);
  const res: Obj = {
    vapidPublicKey: await secret("vapid_public_key"),
    channels: { push: !!d.push_subscription, email: d.email_verified, telegram: !!d.telegram_chat_id },
    emailAddress: d.email_verified ? d.email : null,
    // The server may switch a channel (push -> email after repeated failures): the client adopts these.
    reminders: rs ?? [],
  };
  if (body.telegramLink === true) {
    const bot = await secret("telegram_bot_username");
    res.telegramLink = { code: d.telegram_link_code, url: `https://t.me/${bot}?start=${d.telegram_link_code}` };
  }
  return json(res);
}));
