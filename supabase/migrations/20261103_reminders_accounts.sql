-- Reminders per account (docs/plan-cuentas.md, task A2).
--
-- Signed-in callers (Authorization: Bearer <user JWT>, validated by the Edge
-- Functions) own ONE reminder set, Telegram link and verified email per
-- account, stored under user_id. Callers without a JWT keep the device
-- behavior: rows keyed by device_token, user_id null. Push subscriptions stay
-- per device; a device row carries user_id while its owner is signed in.
--
-- RLS stays enabled with NO policies and no grants for anon/authenticated:
-- only the Edge Functions (service role) touch these tables.

-- Account-level channel settings (what reminder_devices holds in device mode,
-- minus the push subscription).
create table public.reminder_accounts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  timezone text not null default 'UTC',
  quiet_start time,
  quiet_end time,
  email text check (email is null or char_length(email) <= 254),
  email_verified boolean not null default false,
  telegram_chat_id bigint,
  telegram_link_code text unique,
  updated_at timestamptz not null default now()
);
alter table public.reminder_accounts enable row level security;
revoke all on public.reminder_accounts from anon, authenticated;

-- Push subscriptions: per device, tagged with the signed-in account.
alter table public.reminder_devices
  add column user_id uuid references auth.users (id) on delete set null;
create index reminder_devices_user_idx on public.reminder_devices (user_id) where user_id is not null;

-- reminders: owned by a device OR an account.
alter table public.reminders drop constraint reminders_pkey;
alter table public.reminders alter column device_token drop not null;
alter table public.reminders
  add column user_id uuid references public.reminder_accounts (user_id) on delete cascade;
alter table public.reminders add constraint reminders_device_id_key unique (device_token, id);
alter table public.reminders add constraint reminders_user_id_key unique (user_id, id);
alter table public.reminders add constraint reminders_owner_chk check (num_nonnulls(device_token, user_id) = 1);

-- meal_flags
alter table public.meal_flags drop constraint meal_flags_pkey;
alter table public.meal_flags alter column device_token drop not null;
alter table public.meal_flags
  add column user_id uuid references public.reminder_accounts (user_id) on delete cascade;
alter table public.meal_flags
  add constraint meal_flags_device_key unique (device_token, local_date, meal_type);
alter table public.meal_flags
  add constraint meal_flags_user_key unique (user_id, local_date, meal_type);
alter table public.meal_flags
  add constraint meal_flags_owner_chk check (num_nonnulls(device_token, user_id) = 1);

-- email_codes (pending verification codes)
alter table public.email_codes drop constraint email_codes_pkey;
alter table public.email_codes alter column device_token drop not null;
alter table public.email_codes
  add column user_id uuid references public.reminder_accounts (user_id) on delete cascade;
alter table public.email_codes add constraint email_codes_device_key unique (device_token);
alter table public.email_codes add constraint email_codes_user_key unique (user_id);
alter table public.email_codes
  add constraint email_codes_owner_chk check (num_nonnulls(device_token, user_id) = 1);
