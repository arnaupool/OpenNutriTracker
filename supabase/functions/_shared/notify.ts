// @ts-types="npm:@types/web-push@3.6.4"
import webpush from "npm:web-push@3.6.7";
import { sb, secret } from "./common.ts";

export interface Device {
  device_token: string;
  timezone: string;
  quiet_start: string | null;
  quiet_end: string | null;
  push_subscription: webpush.PushSubscription | null;
  push_failures: number;
  email: string | null;
  email_verified: boolean;
  telegram_chat_id: number | null;
}

export interface Reminder {
  device_token: string;
  id: string;
  type: "weigh_in" | "meal" | "custom";
  meal_type: "breakfast" | "lunch" | "snack" | "dinner" | null;
  label: string;
  time_local: string;
  days: number[];
  channel: "push" | "email" | "telegram";
  enabled: boolean;
  skip_if_logged: boolean;
  last_sent_at: string | null;
}

export interface Payload {
  title: string;
  body: string;
  url: string;
}

const MEAL_WORD = { breakfast: "desayuno", lunch: "almuerzo", snack: "merienda", dinner: "cena" };

export function payloadFor(r: Reminder): Payload {
  const title = "OpenNutriTracker";
  if (r.type === "weigh_in") {
    return { title, body: "Pésate en ayunas antes de beber nada", url: "/#/weightHistory" };
  }
  if (r.type === "meal" && r.meal_type) {
    return {
      title,
      body: `Registra tu ${MEAL_WORD[r.meal_type]}`,
      url: `/#/addMeal?meal=${r.meal_type}`,
    };
  }
  return { title, body: r.label, url: "/" };
}

async function sendPush(sub: webpush.PushSubscription, p: Payload): Promise<void> {
  webpush.setVapidDetails(
    await secret("vapid_subject"),
    await secret("vapid_public_key"),
    await secret("vapid_private_key"),
  );
  await webpush.sendNotification(sub, JSON.stringify(p), { TTL: 3600 });
}

async function sendEmail(to: string, p: Payload): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${await secret("resend_api_key")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: await secret("resend_from"), to, subject: p.body, text: p.body }),
  });
  if (!res.ok) throw new Error(`resend ${res.status}`);
}

export async function sendTelegram(chatId: number, text: string): Promise<void> {
  const token = await secret("telegram_bot_token");
  const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
  if (!res.ok) throw new Error(`telegram ${res.status}`);
}

/** Email if verified, else Telegram if linked, else fail. Returns the channel used. */
async function fallback(d: Device, p: Payload): Promise<string> {
  if (d.email_verified && d.email) {
    await sendEmail(d.email, p);
    return "email";
  }
  if (d.telegram_chat_id) {
    await sendTelegram(d.telegram_chat_id, p.body);
    return "telegram";
  }
  throw new Error("no_channel_available");
}

/** Sends one reminder through its channel. Returns the channel actually used. */
export async function deliver(d: Device, r: Reminder): Promise<string> {
  const p = payloadFor(r);
  const dev = sb.from("reminder_devices");

  if (r.channel === "push") {
    if (d.push_subscription) {
      try {
        await sendPush(d.push_subscription, p);
        if (d.push_failures > 0) {
          await dev.update({ push_failures: 0 }).eq("device_token", d.device_token);
        }
        return "push";
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) {
          // Subscription is gone for good.
          await dev.update({ push_subscription: null, push_failures: 0 }).eq("device_token", d.device_token);
        } else {
          const n = d.push_failures + 1;
          if (n >= 3 && d.email_verified) {
            // Too many consecutive failures: move this device's push reminders to email.
            await dev.update({ push_failures: 0 }).eq("device_token", d.device_token);
            await sb.from("reminders").update({ channel: "email" })
              .eq("device_token", d.device_token).eq("channel", "push");
          } else {
            await dev.update({ push_failures: n }).eq("device_token", d.device_token);
          }
        }
      }
    }
    return await fallback(d, p);
  }
  if (r.channel === "email") {
    if (!d.email_verified || !d.email) throw new Error("email_not_verified");
    await sendEmail(d.email, p);
    return "email";
  }
  if (!d.telegram_chat_id) throw new Error("telegram_not_linked");
  await sendTelegram(d.telegram_chat_id, p.body);
  return "telegram";
}
