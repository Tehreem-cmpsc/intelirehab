-- Forces a physiotherapist to set their own password on first login,
-- since the admin currently sets an initial one directly (no SMTP
-- configured yet — see supabase_rls_hardening.sql / conversation history).
-- Every existing physiotherapist also got their password set by an admin
-- under the current flow, so defaulting this to true for pre-existing
-- rows too is correct, not an oversight.
--
-- Safe to run any time — idempotent.

alter table public.physiotherapists
  add column if not exists must_reset_password boolean not null default true;

-- No policy existed for a physio to update their own row at all — needed
-- so they can clear this flag themselves after setting a real password.
-- The app only ever sends { must_reset_password: false } through this
-- policy; it isn't restricted to that single column at the database
-- level, matching how ClinicProfilePanel already trusts the app layer
-- rather than column-level grants elsewhere in this schema.
drop policy if exists "Physios can update their own profile" on public.physiotherapists;
create policy "Physios can update their own profile"
  on public.physiotherapists for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
