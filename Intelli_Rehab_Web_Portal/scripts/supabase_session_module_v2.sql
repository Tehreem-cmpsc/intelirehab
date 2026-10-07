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
--  * patient_exercise_plans.rest_seconds, sessions.rest_seconds
--                      how long the patient rests between sets (set per exercise by the physio, default 30
--                      s in the app) and how long they actually rested in a session. assign_exercise_session
--                      is replaced here so it saves the rest length; run this script AFTER
--                      supabase_assign_session_rpc.sql, or re-run it, so the newer version stays in place.
--
-- Run after supabase_core_tables.sql, supabase_assign_session_rpc.sql and supabase_session_motion.sql.
-- Safe to run any time - idempotent.
-- The app keeps working before this is run: sessions still save, just without these extras.

-- ---- rest between sets ---------------------------------------------------------------------------

alter table public.patient_exercise_plans
  add column if not exists rest_seconds smallint;

alter table public.patient_exercise_plans drop constraint if exists patient_exercise_plans_rest_check;
alter table public.patient_exercise_plans add constraint patient_exercise_plans_rest_check
  check (rest_seconds is null or rest_seconds between 10 and 300);

alter table public.sessions
  add column if not exists rest_seconds integer;

alter table public.sessions drop constraint if exists sessions_rest_seconds_check;
alter table public.sessions add constraint sessions_rest_seconds_check
  check (rest_seconds is null or rest_seconds >= 0);

-- The same function as supabase_assign_session_rpc.sql, plus the rest length per exercise.
create or replace function public.assign_exercise_session(
  p_patient_id uuid,
  p_physio_id  uuid,
  p_plan_name  text,
  p_start_date date,
  p_exercises  jsonb  -- [{exerciseId, sets, reps, romTarget, frequency, restSeconds}, ...]
)
returns uuid
language plpgsql
as $$
declare
  new_plan_id uuid;
begin
  if p_exercises is null or jsonb_array_length(p_exercises) = 0 then
    raise exception 'Select at least one exercise.';
  end if;

  update public.patient_exercise_plans
     set active = false
   where patient_id = p_patient_id and active;

  update public.rehabilitation_plans
     set status = 'completed', end_date = p_start_date
   where patient_id = p_patient_id and status = 'active';

  insert into public.rehabilitation_plans (patient_id, physio_id, plan_name, start_date, status)
  values (p_patient_id, p_physio_id,
          coalesce(nullif(trim(p_plan_name), ''), 'Exercise session'),
          p_start_date, 'active')
  returning id into new_plan_id;

  insert into public.patient_exercise_plans
    (patient_id, exercise_id, assigned_by, plan_id, sets, reps, rom_target, frequency, rest_seconds, active)
  select p_patient_id,
         (e->>'exerciseId')::uuid,
         p_physio_id,
         new_plan_id,
         (e->>'sets')::int,
         (e->>'reps')::int,
         nullif(e->>'romTarget', '')::int,
         e->>'frequency',
         nullif(e->>'restSeconds', '')::int,
         true
  from jsonb_array_elements(p_exercises) as e;

  return new_plan_id;
end;
$$;

revoke all on function public.assign_exercise_session(uuid, uuid, text, date, jsonb) from public, anon;
grant execute on function public.assign_exercise_session(uuid, uuid, text, date, jsonb) to authenticated;

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
