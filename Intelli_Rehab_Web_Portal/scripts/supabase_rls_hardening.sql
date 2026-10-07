-- Follow-up hardening pass after the schema audit (2026-09-23).
-- Run after supabase_credentialing_and_approval.sql.
-- Safe to run any time — does not touch existing row data.

-- 1. patient_badges: block client-side self-awarding.
-- A patient's own authenticated session could otherwise insert any
-- badge_id into their own history. Only a physio (or a future
-- SECURITY DEFINER function that verifies the real condition) should
-- be able to award one.
drop policy if exists "System can award badges" on public.patient_badges;
drop policy if exists "Physios can award badges" on public.patient_badges;
create policy "Physios can award badges"
  on public.patient_badges for insert
  with check (public.is_physio_of_patient(patient_id));

-- 2. exercises / badges: replace the deprecated auth.role() check.
-- auth.role() = 'authenticated' also passes for anonymous sign-ins;
-- `to authenticated` is the current recommended pattern.
drop policy if exists "Authenticated users can view exercises" on public.exercises;
create policy "Authenticated users can view exercises"
  on public.exercises for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can view badge catalog" on public.badges;
create policy "Authenticated users can view badge catalog"
  on public.badges for select
  to authenticated
  using (true);

-- 3. patients.clinic_id: a foreign key should never default to a
-- freshly generated random UUID — it must be supplied explicitly on
-- every insert, or the row silently points at a clinic that doesn't
-- exist.
alter table public.patients alter column clinic_id drop default;
