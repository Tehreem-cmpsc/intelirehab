-- Exercise-session module, round 2: per-set results, pain and early-end reasons on a session, and
-- per-patient safety limits the physiotherapist can set from the portal.
--
--  * session_sets      one row per set of a session (reps, ROM, prompts, fatigue). The app writes them
--                      right after the session row with the session's client id, so a retry is a no-op.
--  * sessions.pain_level, sessions.ended_reason
--                      the patient's 0-10 pain rating at the end, and why a session ended early.
--  * patients.safety_max_angle_deg, patients.safety_max_speed_deg_s
--                      the red "stop" limits for this patient. NULL = the app's built-in default.
--
-- Run after supabase_core_tables.sql and supabase_session_motion.sql. Safe to run any time - idempotent.
-- The app keeps working before this is run: sessions still save, just without these extras.

-- ---- sessions: pain + why it ended ---------------------------------------------------------------

alter table public.sessions
  add column if not exists pain_level   smallint,
  add column if not exists ended_reason text;

alter table public.sessions drop constraint if exists sessions_pain_level_check;
alter table public.sessions add constraint sessions_pain_level_check
  check (pain_level is null or pain_level between 0 and 10);

alter table public.sessions drop constraint if exists sessions_ended_reason_check;
alter table public.sessions add constraint sessions_ended_reason_check
  check (ended_reason is null or ended_reason in ('pain', 'tired', 'band_problem', 'other'));

-- ---- per-set results -----------------------------------------------------------------------------

create table if not exists public.session_sets (
  session_id   uuid not null references public.sessions(id) on delete cascade,
  set_number   smallint not null,
  created_at   timestamptz not null default now(),
  reps         integer not null default 0,
  rom          integer,                 -- peak % of the patient's reference range reached in this set
  corrections  integer not null default 0,
  unsafe       integer not null default 0,
  fatigue      smallint not null default 0,   -- 0 normal .. 3 critical, as sessions.fatigue
  primary key (session_id, set_number),
  constraint session_sets_number_check check (set_number >= 1),
  constraint session_sets_reps_check check (reps >= 0),
  constraint session_sets_fatigue_check check (fatigue between 0 and 3)
);

alter table public.session_sets enable row level security;

drop policy if exists "Clinic staff can view session sets" on public.session_sets;
create policy "Clinic staff can view session sets"
  on public.session_sets for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = session_sets.session_id
        and (public.is_physio_of_patient(s.patient_id) or public.is_admin_of_patient(s.patient_id))
    )
  );

drop policy if exists "Patients can view their own session sets" on public.session_sets;
create policy "Patients can view their own session sets"
  on public.session_sets for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = session_sets.session_id and public.is_own_patient(s.patient_id)
    )
  );

drop policy if exists "Patients can record their own session sets" on public.session_sets;
create policy "Patients can record their own session sets"
  on public.session_sets for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = session_sets.session_id and public.is_own_patient(s.patient_id)
    )
  );

grant select, insert on public.session_sets to authenticated;

-- ---- the clinic's own at-risk rules ---------------------------------------------------------------
-- Edited by the clinic administrator on the portal's Clinic profile page (the existing "Admins can
-- update their own clinic" policy covers it); physiotherapists read it with their clinic row. NULL =
-- the portal's built-in defaults.

alter table public.clinics
  add column if not exists risk_settings jsonb;

-- ---- per-patient safety limits -------------------------------------------------------------------
-- Written by the patient's physiotherapist from the portal (the existing physio UPDATE policy on
-- patients covers it); the patient's app only reads them.

alter table public.patients
  add column if not exists safety_max_angle_deg   smallint,
  add column if not exists safety_max_speed_deg_s smallint;

alter table public.patients drop constraint if exists patients_safety_max_angle_check;
alter table public.patients add constraint patients_safety_max_angle_check
  check (safety_max_angle_deg is null or safety_max_angle_deg between 60 and 180);

alter table public.patients drop constraint if exists patients_safety_max_speed_check;
alter table public.patients add constraint patients_safety_max_speed_check
  check (safety_max_speed_deg_s is null or safety_max_speed_deg_s between 60 and 1000);
