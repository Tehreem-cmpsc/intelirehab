-- ============================================================
-- Full live-schema snapshot — captured 2026-09-23 during a schema
-- audit (information_schema + pg_policies dumped from the live
-- project and diffed by hand). Everything below already exists on
-- the live database; none of it was previously committed to this
-- repo. This file exists so the schema is reproducible from source
-- control instead of living only in the Supabase dashboard.
--
-- Depends on supabase_core_tables.sql having been run first — it
-- defines is_admin_of_clinic, is_physio_of_clinic, is_admin_of_patient,
-- is_physio_of_patient, and is_own_patient, all reused below.
--
-- Every statement is idempotent (add column if not exists / create
-- table if not exists / drop+create policy), so running this against
-- the live project is a safe no-op. Its real purpose is standing up
-- a *new* environment from a clean database.
--
-- NOT captured here: CHECK constraints, triggers, and indexes beyond
-- primary keys — the audit queries didn't inspect those. If any exist
-- live (e.g. an enum-style CHECK on alerts.severity), add them here
-- once confirmed.
-- ============================================================

-- ============================================================
-- 1. patients — columns observed live that predate every committed
--    migration (this table already existed before supabase_setup.sql
--    or supabase_core_tables.sql ever ran against it).
-- ============================================================
alter table public.patients
  add column if not exists name             text not null default '',
  add column if not exists email            text not null default '',
  add column if not exists phone            text not null default '',
  add column if not exists date_of_birth    date not null default '1970-01-01',
  add column if not exists gender           text not null default '',
  add column if not exists injury_side      text not null default '',
  add column if not exists risk_level       text,
  add column if not exists notes            text,
  add column if not exists injury_severity  text,
  add column if not exists diagnosis_date   date,
  add column if not exists recovery_stage   text,
  add column if not exists created_at       timestamptz;

-- Live has patients.clinic_id as NOT NULL (supabase_core_tables.sql
-- left it nullable) — tighten to match, now that
-- supabase_rls_hardening.sql has already dropped its bad
-- gen_random_uuid() default.
alter table public.patients alter column clinic_id set not null;

-- ============================================================
-- 2. rehabilitation_plans — the plan a physio builds for a patient;
--    patient_exercise_plans (below) nests under it via plan_id.
-- ============================================================
create table if not exists public.rehabilitation_plans (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid not null references public.patients(id) on delete cascade,
  physio_id   uuid references public.physiotherapists(id) on delete set null,
  plan_name   text,
  start_date  date,
  end_date    date
);

create index if not exists rehabilitation_plans_patient_id_idx on public.rehabilitation_plans (patient_id);

alter table public.rehabilitation_plans enable row level security;

drop policy if exists "Admins can view rehab plans in their clinic" on public.rehabilitation_plans;
create policy "Admins can view rehab plans in their clinic"
  on public.rehabilitation_plans for select
  using (public.is_admin_of_patient(patient_id));

drop policy if exists "Patients can view their own rehab plans" on public.rehabilitation_plans;
create policy "Patients can view their own rehab plans"
  on public.rehabilitation_plans for select
  using (public.is_own_patient(patient_id));

drop policy if exists "Physios can manage rehab plans for their patients" on public.rehabilitation_plans;
create policy "Physios can manage rehab plans for their patients"
  on public.rehabilitation_plans for all
  using (public.is_physio_of_patient(patient_id))
  with check (public.is_physio_of_patient(patient_id));

grant select, insert, update, delete on public.rehabilitation_plans to authenticated;

-- ============================================================
-- 3. wearable_devices — a patient's registered device.
--    sessions.device_id (below) points at the device used.
-- ============================================================
create table if not exists public.wearable_devices (
  id                uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references public.patients(id) on delete cascade,
  serial_no         text,
  mac_address       text,
  firmware_version  text,
  status            text not null default 'unregistered',
  created_at        timestamptz not null default now()
);

create index if not exists wearable_devices_patient_id_idx on public.wearable_devices (patient_id);

alter table public.wearable_devices enable row level security;

drop policy if exists "Clinic staff can view a patient's device" on public.wearable_devices;
create policy "Clinic staff can view a patient's device"
  on public.wearable_devices for select
  using (public.is_physio_of_patient(patient_id) or public.is_admin_of_patient(patient_id));

drop policy if exists "Patients can view their own device" on public.wearable_devices;
create policy "Patients can view their own device"
  on public.wearable_devices for select
  using (public.is_own_patient(patient_id));

drop policy if exists "Patients can register or update their own device" on public.wearable_devices;
create policy "Patients can register or update their own device"
  on public.wearable_devices for all
  using (public.is_own_patient(patient_id))
  with check (public.is_own_patient(patient_id));

grant select, insert, update, delete on public.wearable_devices to authenticated;

-- ============================================================
-- 4. sessions / patient_exercise_plans / emg_readings — extra
--    columns observed live, added after supabase_core_tables.sql.
-- ============================================================
alter table public.sessions
  add column if not exists device_id uuid references public.wearable_devices(id) on delete set null;

alter table public.patient_exercise_plans
  add column if not exists plan_id uuid references public.rehabilitation_plans(id) on delete set null;

alter table public.emg_readings
  add column if not exists recorded_at timestamptz not null default now();

-- ============================================================
-- 5. sensor_readings — raw IMU stream per session.
-- ============================================================
create table if not exists public.sensor_readings (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references public.sessions(id) on delete cascade,
  recorded_at  timestamptz not null default now(),
  imu_acc_x    real,
  imu_acc_y    real,
  imu_acc_z    real,
  gyro_x       real,
  gyro_y       real,
  gyro_z       real
);

create index if not exists sensor_readings_session_id_idx on public.sensor_readings (session_id);

alter table public.sensor_readings enable row level security;

drop policy if exists "Clinic staff can view sensor readings" on public.sensor_readings;
create policy "Clinic staff can view sensor readings"
  on public.sensor_readings for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = sensor_readings.session_id
        and (public.is_physio_of_patient(s.patient_id) or public.is_admin_of_patient(s.patient_id))
    )
  );

drop policy if exists "Patients can view their own sensor readings" on public.sensor_readings;
create policy "Patients can view their own sensor readings"
  on public.sensor_readings for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = sensor_readings.session_id
        and public.is_own_patient(s.patient_id)
    )
  );

drop policy if exists "Insert sensor readings alongside a session" on public.sensor_readings;
create policy "Insert sensor readings alongside a session"
  on public.sensor_readings for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = sensor_readings.session_id
        and (public.is_own_patient(s.patient_id) or public.is_physio_of_patient(s.patient_id))
    )
  );

grant select, insert on public.sensor_readings to authenticated;

-- ============================================================
-- 6. movement_analysis — per-session AI movement assessment.
-- ============================================================
create table if not exists public.movement_analysis (
  id                     uuid primary key default gen_random_uuid(),
  session_id             uuid not null references public.sessions(id) on delete cascade,
  analyzed_at            timestamptz not null default now(),
  joint_angle            real,
  rom                    real,
  repetition_count       integer,
  movement_score         real,
  posture_status         text,
  compensation_detected  boolean not null default false,
  fatigue_level          text
);

create index if not exists movement_analysis_session_id_idx on public.movement_analysis (session_id);

alter table public.movement_analysis enable row level security;

drop policy if exists "Clinic staff can view movement analysis" on public.movement_analysis;
create policy "Clinic staff can view movement analysis"
  on public.movement_analysis for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = movement_analysis.session_id
        and (public.is_physio_of_patient(s.patient_id) or public.is_admin_of_patient(s.patient_id))
    )
  );

drop policy if exists "Patients can view their own movement analysis" on public.movement_analysis;
create policy "Patients can view their own movement analysis"
  on public.movement_analysis for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = movement_analysis.session_id
        and public.is_own_patient(s.patient_id)
    )
  );

drop policy if exists "Insert movement analysis alongside a session" on public.movement_analysis;
create policy "Insert movement analysis alongside a session"
  on public.movement_analysis for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = movement_analysis.session_id
        and (public.is_own_patient(s.patient_id) or public.is_physio_of_patient(s.patient_id))
    )
  );

grant select, insert on public.movement_analysis to authenticated;

-- ============================================================
-- 7. alerts — corrective-feedback alerts tied to a session and/or
--    a movement analysis, with a physio acknowledgment workflow.
-- ============================================================
create table if not exists public.alerts (
  id                uuid primary key default gen_random_uuid(),
  session_id        uuid references public.sessions(id) on delete cascade,
  analysis_id       uuid references public.movement_analysis(id) on delete cascade,
  alert_type        text not null,
  severity          text not null,
  message           text,
  created_at        timestamptz not null default now(),
  acknowledged_by   uuid references public.physiotherapists(id) on delete set null,
  acknowledged_at   timestamptz
);

create index if not exists alerts_session_id_idx on public.alerts (session_id);

alter table public.alerts enable row level security;

drop policy if exists "Clinic staff can view alerts" on public.alerts;
create policy "Clinic staff can view alerts"
  on public.alerts for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = alerts.session_id
        and (public.is_physio_of_patient(s.patient_id) or public.is_admin_of_patient(s.patient_id))
    )
  );

drop policy if exists "Patients can view their own alerts" on public.alerts;
create policy "Patients can view their own alerts"
  on public.alerts for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = alerts.session_id
        and public.is_own_patient(s.patient_id)
    )
  );

drop policy if exists "Insert alerts alongside a session" on public.alerts;
create policy "Insert alerts alongside a session"
  on public.alerts for insert
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = alerts.session_id
        and (public.is_own_patient(s.patient_id) or public.is_physio_of_patient(s.patient_id))
    )
  );

drop policy if exists "Physios can acknowledge alerts" on public.alerts;
create policy "Physios can acknowledge alerts"
  on public.alerts for update
  using (
    exists (
      select 1 from public.sessions s
      where s.id = alerts.session_id
        and public.is_physio_of_patient(s.patient_id)
    )
  )
  with check (
    exists (
      select 1 from public.sessions s
      where s.id = alerts.session_id
        and public.is_physio_of_patient(s.patient_id)
    )
  );

grant select, insert, update on public.alerts to authenticated;

-- ============================================================
-- 8. badges / patient_badges — achievement catalog + award history.
--    patient_badges' insert policy is the hardened version from
--    supabase_rls_hardening.sql (physio-only, not self-serve).
-- ============================================================
create table if not exists public.badges (
  id           uuid primary key default gen_random_uuid(),
  code         text not null,
  name         text not null,
  description  text,
  icon_url     text
);

alter table public.badges enable row level security;

drop policy if exists "Authenticated users can view badge catalog" on public.badges;
create policy "Authenticated users can view badge catalog"
  on public.badges for select
  to authenticated
  using (true);

grant select on public.badges to authenticated;

create table if not exists public.patient_badges (
  id          uuid primary key default gen_random_uuid(),
  patient_id  uuid not null references public.patients(id) on delete cascade,
  badge_id    uuid not null references public.badges(id) on delete cascade,
  earned_at   timestamptz not null default now()
);

create index if not exists patient_badges_patient_id_idx on public.patient_badges (patient_id);

alter table public.patient_badges enable row level security;

drop policy if exists "Clinic staff can view patient badges" on public.patient_badges;
create policy "Clinic staff can view patient badges"
  on public.patient_badges for select
  using (public.is_physio_of_patient(patient_id) or public.is_admin_of_patient(patient_id));

drop policy if exists "Patients can view their own badges" on public.patient_badges;
create policy "Patients can view their own badges"
  on public.patient_badges for select
  using (public.is_own_patient(patient_id));

drop policy if exists "Physios can award badges" on public.patient_badges;
create policy "Physios can award badges"
  on public.patient_badges for insert
  with check (public.is_physio_of_patient(patient_id));

grant select, insert on public.patient_badges to authenticated;
