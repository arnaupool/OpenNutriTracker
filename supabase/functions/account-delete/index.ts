import { caller, handle, json, sb } from "../_shared/common.ts";

// Deletes the signed-in caller's account: encrypted records, wrapped keys,
// reminder rows and push subscriptions, then the auth user itself. The caller
// can only ever delete themself (the uid comes from the verified JWT).
Deno.serve(handle(async (req) => {
  const who = await caller(req);
  if (who.kind !== "user") return json({ error: "unauthorized" }, 401);
  const uid = who.uid;

  const steps = [
    sb.from("account_records").delete().eq("user_id", uid),
    sb.from("account_keys").delete().eq("user_id", uid),
    // Cascades to reminders, meal_flags and email_codes of the account.
    sb.from("reminder_accounts").delete().eq("user_id", uid),
    // Devices stay (they may keep working in local mode) but lose the subscription.
    sb.from("reminder_devices").update({ user_id: null, push_subscription: null, push_failures: 0 })
      .eq("user_id", uid),
  ];
  for (const step of steps) {
    const { error } = await step;
    if (error) throw error;
  }

  const { error } = await sb.auth.admin.deleteUser(uid);
  if (error) throw error;
  return json({ ok: true });
}));
