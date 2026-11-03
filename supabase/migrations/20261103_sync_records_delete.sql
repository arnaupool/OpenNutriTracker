-- Retiring an old pairing (docs/plan-cuentas.md, task B6): once a profile's
-- first account sync has uploaded everything, the client deletes the rows of
-- its pairing token from sync_records and forgets the token. Same access
-- model as the other token policies: anon, limited by RLS to the rows whose
-- token matches the `x-sync-token` header. Task D11 drops the table.

grant delete on public.sync_records to anon;

create policy "sync: delete own token"
on public.sync_records for delete to anon
using (token = public.sync_request_token());
