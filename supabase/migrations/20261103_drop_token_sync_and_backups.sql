-- D11: the QR-code sync (public.sync_records, keyed by a pairing token) and
-- the cloud backup (storage bucket `backups`) are gone from the app. Accounts
-- sync through public.account_records.

-- account_records used sync_records' trigger function: give it its own.
create function public.account_records_before_write()
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

drop trigger account_records_before_write on public.account_records;
create trigger account_records_before_write
before insert or update on public.account_records
for each row execute function public.account_records_before_write();

drop table public.sync_records;
drop function public.sync_records_before_write();
drop function public.sync_request_token();

-- Cloud backup: the bucket's token-based policies. The bucket and its
-- objects are removed through the Storage API (SQL deletes are blocked).
drop policy "backups: anon can delete own-token object" on storage.objects;
drop policy "backups: anon can overwrite own-token object" on storage.objects;
drop policy "backups: anon can upload own-token object" on storage.objects;
drop policy "backups: anon can read own-token object" on storage.objects;
