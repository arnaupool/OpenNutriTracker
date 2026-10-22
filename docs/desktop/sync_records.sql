-- FAS-01: record-level sync between the phone and the desktop web build.
-- Applied to the backup project as migration "create_sync_records".
--
-- One row per local record (box + id) per pairing token. The payload is
-- AES-encrypted on the device with a key that travels only in the pairing
-- QR, so the server only ever stores opaque text.
--
-- Access model, same as the backup bucket (docs/cloud-backup-setup.md):
-- no login; the 256-bit pairing token is the credential. The client sends
-- it in the `x-sync-token` header and RLS limits every read and write to
-- rows carrying that token.

create table public.sync_records (
  token text not null check (token ~ '^[a-f0-9]{64}$'),
  box text not null check (char_length(box) between 1 and 64),
  id text not null check (char_length(id) between 1 and 200),
  -- base64 ciphertext; null for a deletion tombstone
  payload text check (payload is null or octet_length(payload) <= 1000000),
  -- client clock of the change: decides conflicts (last write wins)
  modified_at timestamptz not null,
  -- server clock of the write: the pull cursor
  updated_at timestamptz not null default now(),
  deleted boolean not null default false,
  primary key (token, box, id)
);

create index sync_records_pull_idx on public.sync_records (token, updated_at);

-- Stamps the server clock on every write and drops updates older than the
-- stored version, so a device that was offline can't overwrite newer data.
create function public.sync_records_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.modified_at < old.modified_at then
    return null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger sync_records_before_write
before insert or update on public.sync_records
for each row execute function public.sync_records_before_write();

create function public.sync_request_token()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    current_setting('request.headers', true)::json ->> 'x-sync-token',
    ''
  );
$$;

alter table public.sync_records enable row level security;

revoke all on public.sync_records from anon, authenticated;
grant select, insert, update on public.sync_records to anon;

create policy "sync: read own token"
on public.sync_records for select to anon
using (token = public.sync_request_token());

create policy "sync: insert own token"
on public.sync_records for insert to anon
with check (token = public.sync_request_token());

create policy "sync: update own token"
on public.sync_records for update to anon
using (token = public.sync_request_token())
with check (token = public.sync_request_token());
