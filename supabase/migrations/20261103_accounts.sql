-- Accounts (docs/plan-cuentas.md, task A1).
--
-- Supabase Auth (email and password) replaces the pairing token as the
-- credential. Data stays end-to-end encrypted: each account has a random
-- data key, stored here only wrapped with a key derived from the password
-- (and optionally with a recovery key). The server never sees the data key.
--
-- The token-based `sync_records` table is left untouched so devices that
-- have not updated keep syncing; task D11 drops it.

-- Admins: who can open or close sign-ups. Read only through is_admin().
create table public.admin_emails (
  email text primary key check (email = lower(email))
);
alter table public.admin_emails enable row level security;
revoke all on public.admin_emails from anon, authenticated;

insert into public.admin_emails (email) values ('arnau2106@gmail.com');

-- True for a signed-in user whose confirmed email is in admin_emails. Looks
-- the email up in auth.users instead of trusting the JWT claim, so an
-- unconfirmed sign-up with an admin's address never counts.
create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    join public.admin_emails a on a.email = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- App-wide settings, one row.
create table public.app_settings (
  id boolean primary key default true check (id),
  signups_open boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.app_settings default values;

alter table public.app_settings enable row level security;
revoke all on public.app_settings from anon, authenticated;
grant select on public.app_settings to anon, authenticated;
grant update (signups_open) on public.app_settings to authenticated;

create policy "settings: anyone can read"
on public.app_settings for select to anon, authenticated
using (true);

create policy "settings: admins can update"
on public.app_settings for update to authenticated
using (public.is_admin())
with check (public.is_admin());

-- Enforces closed sign-ups on the server. The app checks app_settings first
-- to show a clear message; this trigger is what actually blocks the insert.
-- Admin addresses can always register.
create function public.accounts_signup_gate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (select signups_open from public.app_settings where id)
     and not exists (select 1 from public.admin_emails where email = lower(new.email)) then
    raise exception 'signups_closed' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.accounts_signup_gate() from public, anon, authenticated;

create trigger accounts_signup_gate
before insert on auth.users
for each row execute function public.accounts_signup_gate();

-- The account's data key, wrapped. All binary fields are base64.
--   wrapped_key: nonce || AES-256-GCM(data key) under PBKDF2(password, salt)
--   recovery_wrapped_key: same, under the optional recovery key
--   needs_rewrap: set after a password reset done on a device that did not
--     hold the data key; a device that does hold it asks for the new
--     password and wraps again.
create table public.account_keys (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  kdf text not null default 'pbkdf2-sha256' check (kdf in ('pbkdf2-sha256')),
  iterations integer not null check (iterations between 100000 and 10000000),
  salt text not null check (char_length(salt) between 16 and 128),
  wrapped_key text not null check (char_length(wrapped_key) between 32 and 256),
  recovery_salt text check (recovery_salt is null or char_length(recovery_salt) between 16 and 128),
  recovery_wrapped_key text check (recovery_wrapped_key is null or char_length(recovery_wrapped_key) between 32 and 256),
  needs_rewrap boolean not null default false,
  version integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.account_keys enable row level security;
revoke all on public.account_keys from anon, authenticated;
grant select, insert, update on public.account_keys to authenticated;

create policy "keys: read own"
on public.account_keys for select to authenticated
using (user_id = auth.uid());

create policy "keys: insert own"
on public.account_keys for insert to authenticated
with check (user_id = auth.uid());

create policy "keys: update own"
on public.account_keys for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create function public.account_keys_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger account_keys_touch
before insert or update on public.account_keys
for each row execute function public.account_keys_touch();

-- Synced records per account. Same shape and conflict rule as
-- sync_records: `box` and `id` are HMACs under the data key and `payload`
-- is AES-GCM ciphertext.
create table public.account_records (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  box text not null check (char_length(box) between 1 and 64),
  id text not null check (char_length(id) between 1 and 200),
  payload text check (payload is null or octet_length(payload) <= 1000000),
  modified_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  primary key (user_id, box, id)
);

create index account_records_pull_idx on public.account_records (user_id, updated_at);

create trigger account_records_before_write
before insert or update on public.account_records
for each row execute function public.sync_records_before_write();

alter table public.account_records enable row level security;
revoke all on public.account_records from anon, authenticated;
grant select, insert, update on public.account_records to authenticated;

create policy "records: read own"
on public.account_records for select to authenticated
using (user_id = auth.uid());

create policy "records: insert own"
on public.account_records for insert to authenticated
with check (user_id = auth.uid());

create policy "records: update own"
on public.account_records for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
