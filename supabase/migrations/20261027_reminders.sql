-- Web/email/Telegram reminders (task 7 of docs/plan-recordatorios-y-contador.md).
--
-- Privacy: no weights or foods are stored. Only times, ISO weekdays, time
-- zone, label, channel, flags, push subscription, email, Telegram chat id and
-- per-day "meal X logged on local date D" booleans.
--
-- Access model, same idea as sync_records: no login. Each device owns a random
-- 64-hex `device_token` sent in the `x-reminder-device` header. The Edge
-- Functions use the service role and check the header themselves, so the
-- tables have RLS enabled with NO policies: anon/authenticated see nothing.

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists supabase_vault;

create table public.reminder_devices (
  device_token text primary key check (device_token ~ '^[a-f0-9]{64}$'),
  timezone text not null default 'UTC',
  quiet_start time,
  quiet_end time,
  push_subscription jsonb,
  push_failures int not null default 0,
  email text check (email is null or char_length(email) <= 254),
  email_verified boolean not null default false,
  telegram_chat_id bigint,
  telegram_link_code text unique,
  updated_at timestamptz not null default now()
);

create table public.reminders (
  device_token text not null references public.reminder_devices (device_token) on delete cascade,
  id text not null check (id ~ '^[A-Za-z0-9_-]{1,64}$'),
  type text not null check (type in ('weigh_in', 'meal', 'custom')),
  meal_type text check (meal_type in ('breakfast', 'lunch', 'snack', 'dinner')),
  label text not null default '' check (char_length(label) <= 40),
  time_local time not null,
  -- ISO weekdays: 1 = Monday .. 7 = Sunday
  days int[] not null check (days <@ array[1, 2, 3, 4, 5, 6, 7]),
  channel text not null check (channel in ('push', 'email', 'telegram')),
  enabled boolean not null default true,
  skip_if_logged boolean not null default false,
  last_sent_at timestamptz,
  primary key (device_token, id),
  check ((type = 'meal') = (meal_type is not null))
);

create index reminders_enabled_idx on public.reminders (enabled) where enabled;

create table public.meal_flags (
  device_token text not null references public.reminder_devices (device_token) on delete cascade,
  local_date date not null,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'snack', 'dinner')),
  primary key (device_token, local_date, meal_type)
);

create table public.email_codes (
  device_token text primary key references public.reminder_devices (device_token) on delete cascade,
  email text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0
);

alter table public.reminder_devices enable row level security;
alter table public.reminders enable row level security;
alter table public.meal_flags enable row level security;
alter table public.email_codes enable row level security;

revoke all on public.reminder_devices, public.reminders, public.meal_flags, public.email_codes
  from anon, authenticated;

-- Reads a Vault secret. Only the Edge Functions (service role) may call it.
create function public.reminder_secret(name text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets where vault.decrypted_secrets.name = reminder_secret.name;
$$;

revoke all on function public.reminder_secret(text) from public, anon, authenticated;
grant execute on function public.reminder_secret(text) to service_role;

-- Called every minute by pg_cron: prunes old flags and pings reminders-tick.
create function public.reminders_cron()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_url text;
  cron_secret text;
begin
  delete from public.meal_flags where local_date < (now() at time zone 'utc')::date - 3;

  select decrypted_secret into base_url from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into cron_secret from vault.decrypted_secrets where name = 'cron_secret';
  if base_url is null or cron_secret is null then
    return;
  end if;

  perform net.http_post(
    url := rtrim(base_url, '/') || '/functions/v1/reminders-tick',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', cron_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 20000
  );
end;
$$;

revoke all on function public.reminders_cron() from public, anon, authenticated;

select cron.schedule('reminders-tick', '* * * * *', 'select public.reminders_cron()');
