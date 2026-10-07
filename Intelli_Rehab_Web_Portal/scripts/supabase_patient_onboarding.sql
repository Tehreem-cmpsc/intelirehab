-- Patient self-onboarding, Screen 1 (SRS UC-1, extended): a patient creates
-- their own account in the mobile app and self-reports their injury, before
-- they have picked a clinic (Screen 2) or physiotherapist (Screen 3).
--
-- Replaces the reg_id flow in supabase_patient_self_registration.sql for new
-- patients (claim_patient_record is left in place; it's harmless).
--
--   1. patients.clinic_id becomes nullable again — a patient row now exists
--      between Screen 1 and Screen 2 with no clinic. Such rows are invisible
--      to every physio/admin (is_physio_of_clinic(null) is false) until the
--      patient picks a clinic, which is the intended behaviour.
--   2. patients.user_id becomes unique — one patient record per login.
--   3. patient_injuries — the INJURY record (SDD §5.3). The patient fills
--      side, joint, injury type (a plain-language self-report, "not_sure"
--      allowed) and onset date. `description` stays for the physio's own
--      notes; the app no longer asks the patient for free text.
--   4. register_patient_self() — SECURITY DEFINER insert, scoped to exactly
--      the caller's own row, instead of an INSERT RLS policy on patients
--      (same reasoning as claim_patient_record). Idempotent: calling it again
--      for a user who already has a row returns that row, so the app can
--      safely retry after a dropped connection or finish registration on the
--      next sign-in when email confirmation delayed the first attempt.
--
-- Safe to run any time — idempotent. NOTE: step 2 fails if any two live
-- patients rows already share a non-null user_id; resolve those first.

-- ============================================================
-- 1–2. patients
-- ============================================================
alter table public.patients alter column clinic_id drop not null;

alter table public.patients
  add column if not exists terms_accepted_at timestamptz;

create unique index if not exists patients_user_id_key on public.patients (user_id);

-- ============================================================
-- 3. patient_injuries
-- ============================================================
create table if not exists public.patient_injuries (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references public.patients(id) on delete cascade,
  affected_side   text not null check (affected_side in ('left', 'right')),
  affected_joint  text not null check (affected_joint in ('shoulder', 'elbow', 'wrist', 'multiple')),
  injury_type     text,
  diagnosis_date  date,
  description     text,
  source          text not null default 'patient_self_report',
  created_at      timestamptz not null default now()
);

create index if not exists patient_injuries_patient_id_idx on public.patient_injuries (patient_id);

alter table public.patient_injuries enable row level security;

drop policy if exists "Patients can view their own injuries" on public.patient_injuries;
create policy "Patients can view their own injuries"
  on public.patient_injuries for select
  using (public.is_own_patient(patient_id));

drop policy if exists "Staff can view their patients' injuries" on public.patient_injuries;
create policy "Staff can view their patients' injuries"
  on public.patient_injuries for select
  using (public.is_physio_of_patient(patient_id) or public.is_admin_of_patient(patient_id));

drop policy if exists "Physios can manage their patients' injuries" on public.patient_injuries;
create policy "Physios can manage their patients' injuries"
  on public.patient_injuries for all
  using (public.is_physio_of_patient(patient_id))
  with check (public.is_physio_of_patient(patient_id));

-- ============================================================
-- 4. register_patient_self
-- ============================================================
-- The previous version took (…, p_onset_date, p_description); Postgres can't
-- rename a parameter in place, so drop it first.
drop function if exists public.register_patient_self(text, text, date, text, text, text, date, text);

create or replace function public.register_patient_self(
  p_name            text,
  p_phone           text,
  p_date_of_birth   date,
  p_gender          text,
  p_affected_side   text,
  p_affected_joint  text,
  p_injury_type     text,
  p_onset_date      date default null
)
returns public.patients
language plpgsql
security definer
set search_path = public
as $$
declare
  uid          uuid := auth.uid();
  user_email   text;
  new_patient  public.patients;
begin
  if uid is null then
    raise exception 'You need to be signed in to register.';
  end if;

  select * into new_patient from public.patients where user_id = uid;
  if found then
    return new_patient;
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'A name is required.';
  end if;
  if p_affected_side not in ('left', 'right') then
    raise exception 'Affected arm must be left or right.';
  end if;
  if p_affected_joint not in ('shoulder', 'elbow', 'wrist', 'multiple') then
    raise exception 'Affected area is not recognised.';
  end if;
  if p_injury_type not in ('fracture', 'sprain_strain', 'dislocation', 'tendon',
                           'post_surgery', 'stiffness', 'not_sure') then
    raise exception 'Injury type is not recognised.';
  end if;

  -- The login's own email, not a client-supplied one.
  select email into user_email from auth.users where id = uid;

  begin
    insert into public.patients (
      user_id, name, email, phone, date_of_birth, gender,
      injury, injury_side, approved, terms_accepted_at
    )
    values (
      uid, trim(p_name), coalesce(user_email, ''), coalesce(trim(p_phone), ''),
      p_date_of_birth, coalesce(p_gender, ''),
      -- Denormalised copies the web portal already displays as "injury · side".
      case p_affected_joint
        when 'shoulder' then 'Shoulder'
        when 'elbow'    then 'Elbow'
        when 'wrist'    then 'Wrist'
        else 'More than one area'
      end,
      initcap(p_affected_side),
      false,
      now()
    )
    returning * into new_patient;
  exception when unique_violation then
    -- A concurrent call for the same user won the race.
    select * into new_patient from public.patients where user_id = uid;
    return new_patient;
  end;

  insert into public.patient_injuries (
    patient_id, affected_side, affected_joint, injury_type, diagnosis_date
  )
  values (
    new_patient.id, p_affected_side, p_affected_joint, p_injury_type, p_onset_date
  );

  return new_patient;
end;
$$;

grant execute on function public.register_patient_self(text, text, date, text, text, text, text, date) to authenticated;
