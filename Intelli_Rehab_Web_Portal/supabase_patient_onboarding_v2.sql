-- Patient onboarding v2 (mobile app, 6-step flow): richer "About you" and
-- "Your injury" answers. Run AFTER supabase_patient_onboarding.sql.
--
--   Step 1 About you  -> patients.activity_level, patients.dominant_arm
--   Step 2 Your injury -> patient_injuries: affected_side, affected_joint
--                         (now upper_arm / elbow / forearm), injury_type
--                         (new list), cause, diagnosis_date (date of
--                         injury), first_injury, pain_level (0–3)
--   Step 3 Contact     -> the auth login (email / password) + patients.phone
--
-- Older rows keep their values: the affected_joint check still accepts the
-- v1 values (shoulder / wrist / multiple) alongside the new ones.
--
-- Safe to run any time — idempotent.

-- ============================================================
-- 1. New columns
-- ============================================================
alter table public.patients
  add column if not exists activity_level text,
  add column if not exists dominant_arm   text;

alter table public.patients drop constraint if exists patients_activity_level_check;
alter table public.patients add constraint patients_activity_level_check
  check (activity_level is null or activity_level in ('sedentary', 'light', 'active', 'very_active'));

alter table public.patients drop constraint if exists patients_dominant_arm_check;
alter table public.patients add constraint patients_dominant_arm_check
  check (dominant_arm is null or dominant_arm in ('left', 'right', 'both'));

alter table public.patient_injuries
  add column if not exists cause        text,
  add column if not exists first_injury boolean,
  add column if not exists pain_level   smallint;

alter table public.patient_injuries drop constraint if exists patient_injuries_pain_level_check;
alter table public.patient_injuries add constraint patient_injuries_pain_level_check
  check (pain_level is null or pain_level between 0 and 3);

alter table public.patient_injuries drop constraint if exists patient_injuries_cause_check;
alter table public.patient_injuries add constraint patient_injuries_cause_check
  check (cause is null or cause in ('sports', 'fall', 'accident', 'overuse', 'surgery', 'other'));

alter table public.patient_injuries drop constraint if exists patient_injuries_affected_joint_check;
alter table public.patient_injuries add constraint patient_injuries_affected_joint_check
  check (affected_joint in ('upper_arm', 'elbow', 'forearm',
                            -- v1 values, kept for existing rows
                            'shoulder', 'wrist', 'multiple'));

-- ============================================================
-- 2. register_patient_self (v2 signature)
-- ============================================================
drop function if exists public.register_patient_self(text, text, date, text, text, text, text, date);

create or replace function public.register_patient_self(
  p_name            text,
  p_phone           text,
  p_date_of_birth   date,
  p_gender          text,
  p_activity_level  text,
  p_dominant_arm    text,
  p_affected_side   text,
  p_affected_joint  text,
  p_injury_type     text,
  p_injury_cause    text,
  p_injury_date     date,
  p_first_injury    boolean,
  p_pain_level      smallint
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

  -- Idempotent: a retry, or the next sign-in after email confirmation.
  select * into new_patient from public.patients where user_id = uid;
  if found then
    return new_patient;
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'A name is required.';
  end if;
  if p_activity_level not in ('sedentary', 'light', 'active', 'very_active') then
    raise exception 'Activity level is not recognised.';
  end if;
  if p_dominant_arm not in ('left', 'right', 'both') then
    raise exception 'Dominant arm is not recognised.';
  end if;
  if p_affected_side not in ('left', 'right') then
    raise exception 'Injured arm must be left or right.';
  end if;
  if p_affected_joint not in ('upper_arm', 'elbow', 'forearm') then
    raise exception 'Injured area is not recognised.';
  end if;
  if p_injury_type not in ('muscle_strain', 'tendon', 'joint', 'fracture',
                           'post_surgery', 'other') then
    raise exception 'Injury type is not recognised.';
  end if;
  if p_injury_cause not in ('sports', 'fall', 'accident', 'overuse', 'surgery', 'other') then
    raise exception 'How the injury happened is not recognised.';
  end if;
  if p_injury_date is null or p_injury_date > current_date then
    raise exception 'The date of injury is required and cannot be in the future.';
  end if;
  if p_pain_level is null or p_pain_level not between 0 and 3 then
    raise exception 'Pain level must be 0–3.';
  end if;

  -- The login's own email, not a client-supplied one.
  select email into user_email from auth.users where id = uid;

  begin
    insert into public.patients (
      user_id, name, email, phone, date_of_birth, gender,
      activity_level, dominant_arm,
      injury, injury_side, approved, terms_accepted_at
    )
    values (
      uid, trim(p_name), coalesce(user_email, ''), coalesce(trim(p_phone), ''),
      p_date_of_birth, coalesce(p_gender, ''),
      p_activity_level, p_dominant_arm,
      -- Denormalised copies the web portal already displays as "injury · side".
      case p_affected_joint
        when 'upper_arm' then 'Upper arm'
        when 'elbow'     then 'Elbow'
        else 'Forearm'
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
    patient_id, affected_side, affected_joint, injury_type, diagnosis_date,
    cause, first_injury, pain_level
  )
  values (
    new_patient.id, p_affected_side, p_affected_joint, p_injury_type, p_injury_date,
    p_injury_cause, p_first_injury, p_pain_level
  );

  return new_patient;
end;
$$;

grant execute on function public.register_patient_self(
  text, text, date, text, text, text, text, text, text, text, date, boolean, smallint
) to authenticated;
