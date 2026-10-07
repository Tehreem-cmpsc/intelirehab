-- A physiotherapist's at-risk warning (patients.warning, sent from the portal's
-- At Risk page and shown on the patient's Progress screen) erases itself once
-- the patient has done an exercise session AFTER the warning was sent - and the
-- portal keeps a record of which session it was.
--
--  * patients.warning_sent_at is stamped by a trigger whenever a warning is
--    written, and cleared with it.
--  * patients.risk_reviewed_at is set when a warning is sent and never cleared: sending a warning
--    takes the patient off the portal's At Risk list (see assessRisk's `reviewedAt`).
--  * patient_warning_log keeps one row per warning: what it said, when it was
--    sent, and how it ended ('session' - with that session's id, 'physio' - the
--    physio pressed Clear, 'replaced' - a newer warning took its place).
--  * When a session row is inserted, a SECURITY DEFINER trigger clears the
--    patient's warning if the session was performed after warning_sent_at.
--    (Patients have no UPDATE policy on patients, so the app can't do this
--    itself - same reason as supabase_patient_wearable_sync.sql.)
--
-- Only real exercise sessions count: the onboarding baseline calibration
-- session has no exercise_id and is ignored. A session performed before the
-- warning but uploaded later (offline journal) has an earlier start time,
-- so it does not clear a newer warning; and a phone clock a few minutes off
-- does not stop an online session from clearing it (see the trigger below). A warning that predates this script
-- has no warning_sent_at and is cleared by the patient's next session (it has
-- no log row, so only warnings sent from now on appear in the history).
--
-- Run after supabase_core_tables.sql. Safe to run any time - idempotent.

alter table public.patients
  add column if not exists warning_sent_at timestamptz,
  -- When a physiotherapist last sent this patient a warning. Unlike warning_sent_at it is never
  -- cleared: the portal only counts sessions AFTER this moment when deciding who is at risk, so a
  -- warned patient leaves the At Risk list and comes back only if new sessions show a new problem.
  add column if not exists risk_reviewed_at timestamptz;

-- ---- the log -------------------------------------------------------------------------------------

create table if not exists public.patient_warning_log (
  id                 uuid primary key default gen_random_uuid(),
  patient_id         uuid not null references public.patients(id) on delete cascade,
  message            text not null,
  sent_at            timestamptz not null default now(),
  cleared_at         timestamptz,
  cleared_by         text,
  cleared_session_id uuid references public.sessions(id) on delete set null,
  read_at            timestamptz,   -- when the patient tapped "Got it" in the app
  constraint patient_warning_log_cleared_by_check
    check (cleared_by is null or cleared_by in ('session', 'physio', 'replaced'))
);

create index if not exists patient_warning_log_patient_idx
  on public.patient_warning_log (patient_id, sent_at desc);

alter table public.patient_warning_log enable row level security;

drop policy if exists "Clinic staff can view warning history" on public.patient_warning_log;
create policy "Clinic staff can view warning history"
  on public.patient_warning_log for select
  using (public.is_physio_of_patient(patient_id) or public.is_admin_of_patient(patient_id));

-- A patient can read their own warning's row (the app shows whether they already tapped "Got it").
drop policy if exists "Patients can view their own warning log" on public.patient_warning_log;
create policy "Patients can view their own warning log"
  on public.patient_warning_log for select
  using (public.is_own_patient(patient_id));

-- Written only by the triggers below, and by acknowledge_my_warning().
grant select on public.patient_warning_log to authenticated;

-- The patient taps "Got it" on a warning in the app. Patients have no write access to the log, so this
-- (SECURITY DEFINER, touching only their own open warning's read_at) is how the portal learns it was seen.
create or replace function public.acknowledge_my_warning()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.patient_warning_log l
  set read_at = now()
  where l.cleared_at is null
    and l.read_at is null
    and l.patient_id in (select p.id from public.patients p where p.user_id = auth.uid());
end;
$$;

revoke all on function public.acknowledge_my_warning() from public;
grant execute on function public.acknowledge_my_warning() to authenticated;

-- ---- stamp + log whenever the warning column is written -----------------------------------------

create or replace function public.stamp_patient_warning()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  by_session text := nullif(current_setting('inteli.cleared_by_session', true), '');
  has_text   boolean := nullif(btrim(coalesce(new.warning, '')), '') is not null;
begin
  new.warning_sent_at := case when has_text then now() else null end;
  if has_text then
    new.risk_reviewed_at := now();
  end if;

  -- Whatever warning was open ends here: cleared by a session, cleared by the physio, or replaced.
  update public.patient_warning_log
  set cleared_at = now(),
      cleared_by = case
        when by_session is not null then 'session'
        when has_text then 'replaced'
        else 'physio'
      end,
      cleared_session_id = case when by_session is not null then by_session::uuid else null end
  where patient_id = new.id and cleared_at is null;

  if has_text then
    insert into public.patient_warning_log (patient_id, message) values (new.id, new.warning);
  end if;

  return new;
end;
$$;

drop trigger if exists patients_stamp_warning on public.patients;
create trigger patients_stamp_warning
  before update of warning on public.patients
  for each row execute function public.stamp_patient_warning();

-- ---- clear it after the patient's next real session ---------------------------------------------

create or replace function public.clear_warning_after_session()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  duration_s numeric := coalesce((to_jsonb(new) ->> 'duration_seconds')::numeric, 0);
  est_start  timestamptz := new.created_at - make_interval(secs => duration_s);
  started    timestamptz;
begin
  if new.exercise_id is null then
    return null;
  end if;

  -- When the session really started. performed_at comes from the phone's clock, which can be a few
  -- minutes off. A session uploaded as soon as it finished lets the server work it out itself (upload
  -- time minus duration); if the two agree to within 10 minutes the server's figure is used. If they
  -- don't (an offline session uploaded later, or a clock far off) the phone's own time is kept, so an
  -- old queued session can never clear a newer warning.
  started := case
    when abs(extract(epoch from (est_start - new.performed_at))) <= 600 then est_start
    else new.performed_at
  end;

  -- Tell stamp_patient_warning (same transaction) that a session did this, and which one.
  perform set_config('inteli.cleared_by_session', new.id::text, true);

  update public.patients p
  set warning = null
  where p.id = new.patient_id
    and p.warning is not null
    and started > coalesce(p.warning_sent_at, '-infinity'::timestamptz);

  perform set_config('inteli.cleared_by_session', '', true);

  return null;
end;
$$;

drop trigger if exists sessions_clear_warning on public.sessions;
create trigger sessions_clear_warning
  after insert on public.sessions
  for each row execute function public.clear_warning_after_session();
