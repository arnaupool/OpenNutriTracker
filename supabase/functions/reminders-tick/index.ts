import { json, sb } from "../_shared/common.ts";
import { deliver, type Device, type Reminder } from "../_shared/notify.ts";

const WEEKDAY: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
const formatters = new Map<string, Intl.DateTimeFormat>();

/** Local date, HH:MM and ISO weekday for a time zone; null if the zone is invalid. */
function localParts(tz: string, now: Date) {
  let f = formatters.get(tz);
  if (!f) {
    try {
      f = new Intl.DateTimeFormat("en-US", {
        timeZone: tz, hourCycle: "h23", weekday: "short",
        year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit",
      });
    } catch {
      return null;
    }
    formatters.set(tz, f);
  }
  const p = Object.fromEntries(f.formatToParts(now).map((x) => [x.type, x.value]));
  return {
    date: `${p.year}-${p.month}-${p.day}`,
    time: `${p.hour}:${p.minute}`,
    isoDay: WEEKDAY[p.weekday],
  };
}

/** Quiet range [start, end); may cross midnight. Times are "HH:MM[:SS]" strings. */
function inQuietHours(t: string, start: string | null, end: string | null): boolean {
  if (!start || !end) return false;
  const s = start.slice(0, 5), e = end.slice(0, 5);
  if (s === e) return false;
  return s < e ? t >= s && t < e : t >= s || t < e;
}

Deno.serve(async (req) => {
  if (req.headers.get("authorization") !== `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`) {
    return json({ error: "unauthorized" }, 401);
  }
  const now = new Date();
  const { data, error } = await sb.from("reminders").select("*, device:reminder_devices(*)").eq("enabled", true);
  if (error) return json({ error: error.message }, 500);

  let sent = 0;
  await Promise.allSettled((data ?? []).map(async (row) => {
    const { device, ...r } = row as Reminder & { device: Device };
    const lp = localParts(device.timezone, now);
    if (!lp || r.time_local.slice(0, 5) !== lp.time || !r.days.includes(lp.isoDay)) return;
    if (inQuietHours(lp.time, device.quiet_start, device.quiet_end)) return;

    if (r.skip_if_logged && r.type === "meal") {
      const { count } = await sb.from("meal_flags").select("*", { count: "exact", head: true })
        .eq("device_token", r.device_token).eq("local_date", lp.date).eq("meal_type", r.meal_type!);
      if (count) return;
    }

    // Atomic claim: a reminder is sent at most once per 50 s.
    const cutoff = new Date(now.getTime() - 50_000).toISOString();
    const { data: claimed } = await sb.from("reminders").update({ last_sent_at: now.toISOString() })
      .eq("device_token", r.device_token).eq("id", r.id)
      .or(`last_sent_at.is.null,last_sent_at.lt.${cutoff}`).select("id");
    if (!claimed?.length) return;

    try {
      await deliver(device, r);
      sent++;
    } catch (e) {
      console.error(`reminder ${r.id} failed:`, (e as Error).message);
    }
  }));
  return json({ sent });
});
