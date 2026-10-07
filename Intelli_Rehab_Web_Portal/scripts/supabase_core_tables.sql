-- ============================================================
-- Core clinical tables: patients, exercises, exercise plans,
-- sessions, EMG readings, activity log.
--
-- `clinics` and `physiotherapists` already exist (supabase_setup.sql).
-- `patients` already exists too but without a confirmed clinic_id
-- link (see src/domain/admin/useDashboardStats.js) — this script
-- adds the missing columns rather than dropping it, so existing
-- patient rows are NOT touched.
--
-- Safe to run any time — every statement is idempotent.
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1. patients — ensure table + columns exist
-- ============================================================
create table if not exists public.patients (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  full_name  text not null default ''
);

alter table public.patients
  add column if not exists clinic_id           uuid references public.clinics(id) on delete cascade,
  add column if not exists physio_id           uuid references public.physiotherapists(id) on delete set null,
  add column if not exists user_id             uuid references auth.users(id) on delete set null,
  add column if not exists reg_id              text,
  add column if not exists injury              text,
  add column if not exists status              text not null default 'active',
  add column if not exists wearable_connected  boolean not null default false,
  add column if not exists approved            boolean not null default false,
  add column if not exists warning             text;

-- NULLs don't collide under a unique index, so existing rows with no
-- reg_id yet are unaffected.
create unique index if not exists patients_reg_id_key on public.patients (reg_id);
create index if not exists patients_clinic_id_idx on public.patients (clinic_id);

alter table public.patients enable row level security;

-- ============================================================
-- 2. Helper functions (SECURITY DEFINER — bypass RLS to avoid
--    the cross-table recursion described in supabase_fix_rls_recursion.sql)
-- ============================================================
create or replace function public.is_physio_of_patient(target_patient_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.patients p
    where p.id = target_patient_id
      and public.is_physio_of_clinic(p.clinic_id)
  );
$$;

create or replace function public.is_admin_of_patient(target_patient_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.patients p
    where p.id = target_patient_id
      and public.is_admin_of_clinic(p.clinic_id)
  );
$$;

create or replace function public.is_own_patient(target_patient_id uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.patients p
    where p.id = target_patient_id
      and p.user_id = auth.uid()
  );
$$;

grant execute on function public.is_physio_of_patient(uuid) to authenticated;
grant execute on function public.is_admin_of_patient(uuid) to authenticated;
grant execute on function public.is_own_patient(uuid) to authenticated;

-- ============================================================
-- 3. patients policies
-- ============================================================
drop policy if exists "Patients can view their own record" on public.patients;
create policy "Patients can view their own record"
  on public.patients for select
  using (user_id = auth.uid());

drop policy if exists "Physios can view patients in their clinic" on public.patients;
create policy "Physios can view patients in their clinic"
  on public.patients for select
  using (public.is_physio_of_clinic(clinic_id));

drop policy if exists "Admins can view patients in their clinic" on public.patients;
create policy "Admins can view patients in their clinic"
  on public.patients for select
  using (public.is_admin_of_clinic(clinic_id));

drop policy if exists "Physios can add patients to their clinic" on public.patients;
create policy "Physios can add patients to their clinic"
  on public.patients for insert
  with check (public.is_physio_of_clinic(clinic_id));

drop policy if exists "Physios can update patients in their clinic" on public.patients;
create policy "Physios can update patients in their clinic"
  on public.patients for update
  using (public.is_physio_of_clinic(clinic_id))
  with check (public.is_physio_of_clinic(clinic_id));

drop policy if exists "Admins can update patients in their clinic" on public.patients;
create policy "Admins can update patients in their clinic"
  on public.patients for update
  using (public.is_admin_of_clinic(clinic_id))
  with check (public.is_admin_of_clinic(clinic_id));

drop policy if exists "Physios can remove patients from their clinic" on public.patients;
create policy "Physios can remove patients from their clinic"
  on public.patients for delete
  using (public.is_physio_of_clinic(clinic_id));

grant select, insert, update, delete on public.patients to authenticated;

-- ============================================================
-- 4. exercises — shared exercise library (currently hardcoded in
--    src/infrastructure/physio/constants/mockData.js)
-- ============================================================
create table if not exists public.exercises (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  name        text not null,
  target      text,
  difficulty  text not null default 'Beginner', -- 'Beginner' | 'Intermediate' | 'Advanced'
  description text
);

alter table public.exercises enable row level security;

drop policy if exists "Authenticated users can view exercises" on public.exercises;
create policy "Authenticated users can view exercises"
  on public.exercises for select
  using (auth.role() = 'authenticated');

drop policy if exists "Physios can manage exercises" on public.exercises;
create policy "Physios can manage exercises"
  on public.exercises for all
  using (exists (select 1 from public.physiotherapists p where p.user_id = auth.uid()))
  with check (exists (select 1 from public.physiotherapists p where p.user_id = auth.uid()));

grant select, insert, update, delete on public.exercises to authenticated;

-- ============================================================
-- 5. patient_exercise_plans — the "current exercise" a physio
--    assigns a patient (sets/reps/ROM target/frequency)
-- ============================================================
create table if not exists public.patient_exercise_plans (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  patient_id  uuid not null references public.patients(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  assigned_by uuid references public.physiotherapists(id) on delete set null,
  sets        integer not null default 3,
  reps        integer not null default 10,
  rom_target  integer,
  frequency   text,
  active      boolean not null default true
);

create index if not exists patient_exercise_plans_patient_id_idx on public.patient_exercise_plans (patient_id);

alter table public.patient_exercise_plans enable row level security;

drop policy if exists "Clinic staff can view exercise plans" on public.patient_exercise_plans;
create policy "Clinic staff can view exercise plans"
  on public.patient_exercise_plans for select
  using (public.is_physio_of_patient(patient_id) or public.is_admin_of_patient(patient_id));

drop policy if exists "Patients can view their own exercise plans" on public.patient_exercise_plans;
create policy "Patients can view their own exercise plans"
  on public.patient_exercise_plans for select
  using (public.is_own_patient(patient_id));

drop policy if exists "Physios can assign exercise plans" on public.patient_exercise_plans;
create policy "Physios can assign exercise plans"
  on public.patient_exercise_plans for insert
  with check (public.is_physio_of_patient(patient_id));

drop policy if exists "Physios can update exercise plans" on public.patient_exercise_plans;
create policy "Physios can update exercise plans"
  on public.patient_exercise_plans for update
  using (public.is_physio_of_patient(patient_id))
  with check (public.is_physio_of_patient(patient_id));

grant select, insert, update on public.patient_exercise_plans to authenticated;

-- ============================================================
-- 6. sessions — one row per completed rehab session (ROM,
--    quality, fatigue, reps). Feeds "session history" +
--    dashboard stats (sessionsToday, avgRom, weekly ROM trend
--    can be derived by grouping performed_at).
-- ============================================================
create table if not exists public.sessions (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  patient_id   uuid not null references public.patients(id) on delete cascade,
  exercise_id  uuid references public.exercises(id) on delete set null,
  performed_at timestamptz not null default now(),
  rom          integer,
  quality      integer,
  fatigue      integer,
  reps         integer
);

create index if not exists sessions_patient_id_idx on public.sessions (patient_id);
create index if not exists sessions_performed_at_idx on public.sessions (performed_at);

alter table public.sessions enable row level security;

drop policy if exists "Clinic staff can view a patient's sessions" on public.sessions;
create policy "Clinic staff can view a patient's sessions"
  on public.sessions for select
  using (public.is_physio_of_patient(patient_id) or public.is_admin_of_patient(patient_id));

drop policy if exists "Patients can view their own sessions" on public.sessions;
create policy "Patients can view their own sessions"
  on public.sessions for select
  using (public.is_own_patient(patient_id));

drop policy if exists "Patients can log their own sessions" on public.sessions;
create policy "Patients can log their own sessions"
  on public.sessions for insert
  with check (public.is_own_patient(patient_id));

drop policy if exists "Physios can log sessions for their patients" on public.sessions;
create policy "Physios can log sessions for their patients"
  on public.sessions for insert
  with check (public.is_physio_of_patient(patient_id));

grant select, insert on public.sessions to authenticated;

-- ============================================================
-- 7. emg_readings — per-muscle activation values for a session
-- ============================================================
create table if not exists public.emg_readings (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  muscle     text not null,
  value      integer not null
);

create index if not exists emg_readings_session_id_idx on public.emg_readings (session_id);

alter table public.emg_readings enable row level security;

drop policy if exists "Clinic staff can view EMG readings" on public.emg_readings;
create policy "Clinic staff can view EMG readings"
  on public.emg_readings for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = emg_readings.session_id
        and (public.is_physio_of_patient(s.patient_id) or public.is_admin_of_patient(s.patient_id))
    )
  );

drop policy if exists "Patients can view their own EMG readings" on public.emg_readings;
create policy "Patients can view their own EMG readings"
  on public.emg_readings for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = emg_readings.session_id
        and public.is_own_patient(s.patient_id)
    )
  );

drop policy if exists "Insert EMG readings alongside a session" on public.emg_readings;
create policy "Insert EMG readings alongside a session"
  on public.emg_readings for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = emg_readings.session_id
        and (public.is_own_patient(s.patient_id) or public.is_physio_of_patient(s.patient_id))
    )
  );

grant select, insert on public.emg_readings to authenticated;

-- ============================================================
-- 8. activity_log — clinic activity feed (currently MOCK_DB.activity
--    in src/infrastructure/admin/api.js)
-- ============================================================
create table if not exists public.activity_log (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  clinic_id  uuid not null references public.clinics(id) on delete cascade,
  message    text not null
);

create index if not exists activity_log_clinic_id_idx on public.activity_log (clinic_id);

alter table public.activity_log enable row level security;

drop policy if exists "Clinic staff can view their clinic's activity" on public.activity_log;
create policy "Clinic staff can view their clinic's activity"
  on public.activity_log for select
  using (public.is_admin_of_clinic(clinic_id) or public.is_physio_of_clinic(clinic_id));

drop policy if exists "Clinic staff can post activity" on public.activity_log;
create policy "Clinic staff can post activity"
  on public.activity_log for insert
  with check (public.is_admin_of_clinic(clinic_id) or public.is_physio_of_clinic(clinic_id));

grant select, insert on public.activity_log to authenticated;
