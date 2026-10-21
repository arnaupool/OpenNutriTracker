# Cloud backup: Supabase Storage setup

This is the infrastructure half of the "backup en la nube" feature (Kanvas `Fase Cuenta`, FA-09 onward): a private Storage bucket the app can push a full local snapshot to, and pull it back down on a second device. There's no login involved — see the design note below before you run anything.

## Why there's no login

The app talks to Supabase only through the **anon key**. Adding real accounts (Supabase Auth, `auth.uid()`-scoped policies) would mean building a login/signup screen just to gate one private zip file — overkill for a feature whose entire job is "let this one person's own devices see the same data."

Instead, the app generates a random 256-bit token locally the first time you turn on cloud backup, and uses it as part of the object's path. The Storage policy below doesn't check *who* is asking — it only checks that the path looks like a real token (64 lowercase hex characters). Nobody can guess a 256-bit value, and Storage doesn't expose bucket listing to the `anon` role, so there's nothing to enumerate. Practically this is the same security model as a Google Drive "anyone with the link" share: possession of the token is possession of access. Pairing a second device is a one-time QR scan (or copy/paste) of that token — not a password you type on every sync.

This is intentionally *not* meant to scale past "you, and maybe a couple of devices/people you trust with the link." If that ever changes, revisit with real Supabase Auth + `auth.uid()`-scoped policies instead.

## A separate project, not the shared FDC one

Generic-food search no longer uses Supabase at all (it calls the USDA FoodData Central API directly with `FDC_API_KEY`); this backup project is the app's only Supabase project, and it must be your own.

This feature uses its own, separate Supabase project instead -- free tier is plenty (a diary export zip is a few MB at most). Env vars: `BACKUP_SUPABASE_PROJECT_URL` / `BACKUP_SUPABASE_PROJECT_ANON_KEY` in `.env` (see `.env.example`), wired up in `lib/core/utils/locator.dart` as a second `SupabaseClient` registered under the GetIt instance name `'backupSupabase'` -- fetch it with `locator<SupabaseClient>(instanceName: 'backupSupabase')`, not the unnamed one (which is still the food-search client).

Only the **anon / public** key (in the newer Supabase dashboard, the one prefixed `sb_publishable_...`) goes into `.env` -- that's the key meant to be embedded in a client app. The `sb_secret_...` key (the `service_role` equivalent) must never be pasted anywhere in this repo or app: it bypasses RLS entirely, and the whole point of the token-pattern policies below is that the app never needs it.

## What to run

In **your own** Supabase project's dashboard (not the shared FDC one): **SQL Editor → New query**, paste the block below, **Run**.

```sql
-- 1. Private bucket for cloud-backup snapshots. Not public — the RLS
-- policies below are the only way in, there's no anonymous browsing.
insert into storage.buckets (id, name, public)
values ('backups', 'backups', false)
on conflict (id) do nothing;

-- 2. RLS policies on storage.objects, scoped to the 'backups' bucket.
-- Every policy enforces the same path shape:
--   backups/<64 lowercase hex chars>/latest.zip
-- The 64-hex-char segment IS the token the app generates on-device.
-- No table lookup, no Edge Function, no JWT claim -- knowing a valid
-- token is the only thing that grants access.

create policy "backups: anon can read own-token object"
on storage.objects for select
to anon
using (
  bucket_id = 'backups'
  and name ~ '^backups/[a-f0-9]{64}/latest\.zip$'
);

create policy "backups: anon can upload own-token object"
on storage.objects for insert
to anon
with check (
  bucket_id = 'backups'
  and name ~ '^backups/[a-f0-9]{64}/latest\.zip$'
);

create policy "backups: anon can overwrite own-token object"
on storage.objects for update
to anon
using (
  bucket_id = 'backups'
  and name ~ '^backups/[a-f0-9]{64}/latest\.zip$'
)
with check (
  bucket_id = 'backups'
  and name ~ '^backups/[a-f0-9]{64}/latest\.zip$'
);

create policy "backups: anon can delete own-token object"
on storage.objects for delete
to anon
using (
  bucket_id = 'backups'
  and name ~ '^backups/[a-f0-9]{64}/latest\.zip$'
);
```

`storage.objects` has row-level security enabled by default on every Supabase project, so there's no separate "enable RLS" step.

## Verifying it worked

After running the block:

- **Storage → backups** should show the new bucket, empty, with a lock icon (private).
- **Storage → Policies** (or `select * from pg_policies where tablename = 'objects';` in the SQL editor) should list the four `backups: ...` policies above.
- A quick manual sanity check once the app side (FA-15, FA-12) exists: uploading to a path that *doesn't* match the pattern (wrong length, uppercase hex, missing `/latest.zip`) should be rejected by Postgres with a row-level security error, not silently accepted.

## What's next

This bucket is the target for `CloudBackupUsecase`/`CloudRestoreUsecase` (FA-12), which upload/download the same zip `ExportDataUsecase`/`ImportDataUsecase` already build — see FA-11 for the addition of `UserBox`/`ConfigBox` to that snapshot, and FA-15 for how the token itself gets generated and shown to the user as a QR code.
