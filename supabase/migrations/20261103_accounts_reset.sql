-- "Start from scratch" after a password reset without the old data key or a
-- recovery key (docs/plan-cuentas.md): the account deletes its own wrapped
-- key and its unreadable records, then creates a new key. Only own rows.

grant delete on public.account_keys to authenticated;
grant delete on public.account_records to authenticated;

create policy "keys: delete own"
on public.account_keys for delete to authenticated
using (user_id = auth.uid());

create policy "records: delete own"
on public.account_records for delete to authenticated
using (user_id = auth.uid());
