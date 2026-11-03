import {
  accountOwner,
  caller,
  deviceOwner,
  deviceToken,
  ensureAccount,
  ensureDevice,
  handle,
  json,
  type Obj,
  type Owner,
  randomHex,
  readJson,
  sb,
  secret,
} from "../_shared/common.ts";

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const MEALS = ["breakfast", "lunch", "snack", "dinner"];
const TYPES = ["weigh_in", "meal", "custom"];
const CHANNELS = ["push", "email", "telegram"];
const MAX_REMINDERS = 30;

function parseReminder(raw: Obj, owner: Owner): Obj | null {
  const { id, type, mealType, label, time, days, channel } = raw;
  if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) return null;
  if (!TYPES.includes(type) || !CHANNELS.includes(channel)) return null;
  if (typeof time !== "string" || !TIME.test(time)) return null;
  if (!Array.isArray(days) || days.some((d) => !Number.isInteger(d) || d < 1 || d > 7)) return null;
  if ((type === "meal") !== MEALS.includes(mealType)) return null;
  return {
    [owner.col]: owner.val,
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
  const who = await caller(req);
  if (who.kind === "invalid") return json({ error: "invalid_jwt" }, 401);
  const account = who.kind === "user";

  // Device header: required in device mode; in account mode it identifies the
  // device whose push subscription this call manages (optional).
  const rawHeader = req.headers.get("x-reminder-device");
  const token = deviceToken(req);
  if (!token && (!account || rawHeader)) return json({ error: "bad_device" }, 401);

  const body = await readJson(req);
  if (token) await ensureDevice(token);

  // Sign-out / back to local mode: the device stops belonging to the account.
  const detach = body.detachAccount === true && !!token;
  if (detach) {
    const { error } = await sb.from("reminder_devices")
      .update({ user_id: null, push_subscription: null, push_failures: 0 }).eq("device_token", token!);
    if (error) throw error;
  }

  let owner: Owner;
  if (account && !detach) {
    owner = accountOwner(who.uid);
    await ensureAccount(who.uid);
  } else if (token) {
    owner = deviceOwner(token);
  } else {
    return json({ error: "bad_device" }, 401);
  }
  const accountMode = owner.col === "user_id";

  // Meal flag: cheap call made right after the user logs a meal.
  const ml = body.mealLogged;
  if (ml) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(ml.date) || !MEALS.includes(ml.mealType)) {
      return json({ error: "bad_meal_flag" }, 400);
    }
    const { error } = await sb.from("meal_flags").upsert(
      { [owner.col]: owner.val, local_date: ml.date, meal_type: ml.mealType },
      { onConflict: `${owner.col},local_date,meal_type`, ignoreDuplicates: true },
    );
    if (error) throw error;
  }

  // Settings: only the keys present in the body are changed.
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
  if (body.telegramLink === true) patch.telegram_link_code = randomHex(8);

  // Push subscription: always per device.
  const devicePatch: Obj = {};
  if (body.pushSubscription !== undefined) {
    const s = body.pushSubscription;
    if (s !== null && (typeof s?.endpoint !== "string" || !s.endpoint.startsWith("https://"))) {
      return json({ error: "bad_subscription" }, 400);
    }
    if (!token) return json({ error: "device_required" }, 400);
    devicePatch.push_subscription = s;
    devicePatch.push_failures = 0;
  }
  if (accountMode) {
    if (token) devicePatch.user_id = owner.val; // this device now belongs to the account
    const { error } = await sb.from("reminder_accounts").update(patch).eq("user_id", owner.val);
    if (error) throw error;
    if (token && Object.keys(devicePatch).length) {
      const { error: e } = await sb.from("reminder_devices").update(devicePatch).eq("device_token", token);
      if (e) throw e;
    }
  } else {
    const { error } = await sb.from("reminder_devices").update({ ...patch, ...devicePatch })
      .eq("device_token", token!);
    if (error) throw error;
  }

  // Full replace of the reminders list.
  if (Array.isArray(body.reminders)) {
    if (body.reminders.length > MAX_REMINDERS) return json({ error: "too_many_reminders" }, 400);
    const rows = body.reminders.map((r: Obj) => parseReminder(r, owner));
    if (rows.includes(null)) return json({ error: "bad_reminder" }, 400);
    const ids = rows.map((r: Obj) => r.id);
    let del = sb.from("reminders").delete().eq(owner.col, owner.val);
    if (ids.length) del = del.not("id", "in", `(${ids.join(",")})`);
    const { error: delError } = await del;
    if (delError) throw delError;
    if (rows.length) {
      // last_sent_at is not in the rows, so the upsert keeps it.
      const { error } = await sb.from("reminders").upsert(rows, { onConflict: `${owner.col},id` });
      if (error) throw error;
    }
  }

  const { data: d, error: dError } = await sb.from(owner.table).select("*").eq(owner.col, owner.val).single();
  if (dError) throw dError;
  const { data: rs } = await sb.from("reminders").select("id, channel").eq(owner.col, owner.val);

  let push: boolean;
  if (!accountMode) {
    push = !!d.push_subscription;
  } else if (token) {
    const { data: dev } = await sb.from("reminder_devices").select("push_subscription")
      .eq("device_token", token).single();
    push = !!dev?.push_subscription;
  } else {
    const { count } = await sb.from("reminder_devices").select("*", { count: "exact", head: true })
      .eq("user_id", owner.val).not("push_subscription", "is", null);
    push = !!count;
  }

  const res: Obj = {
    vapidPublicKey: await secret("vapid_public_key"),
    channels: { push, email: d.email_verified, telegram: !!d.telegram_chat_id },
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
