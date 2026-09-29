-- Patient Profile screen (SRS gap #4 — no use case defined this, so it's
-- built strictly from existing PATIENT fields, plus the two data-dictionary
-- fields that were documented but never added to the live table: height_cm
-- and weight_kg).
--
-- Lets a patient edit their own name/phone/date of birth/gender/height/
-- weight from the mobile app's Profile screen. Email is deliberately left
-- out — it's the login identifier and isn't a plain inline edit (see the
-- Profile screen's own note); clinic_id/physio_id/approved/status/warning
-- are staff-only fields and also excluded.
--
-- Same reasoning as supabase_patient_self_registration.sql: a blanket
-- UPDATE RLS policy on patients would let a signed-in patient overwrite
-- any column on their own row, including approved/clinic_id/physio_id — so
-- this is a SECURITY DEFINER function scoped to exactly the columns the
-- Profile screen's Personal Info section edits.
--
-- Safe to run any time — idempotent.

alter table public.patients
  add column if not exists height_cm numeric,
  add column if not exists weight_kg numeric;

alter table public.patients drop constraint if exists patients_height_cm_check;
alter table public.patients add constraint patients_height_cm_check
  check (height_cm is null or (height_cm > 0 and height_cm < 300));

alter table public.patients drop constraint if exists patients_weight_kg_check;
alter table public.patients add constraint patients_weight_kg_check
  check (weight_kg is null or (weight_kg > 0 and weight_kg < 500));

create or replace function public.update_patient_profile(
  p_name          text,
  p_phone         text,
  p_date_of_birth date,
  p_gender        text,
  p_height_cm     numeric default null,
  p_weight_kg     numeric default null
)
returns public.patients
language plpgsql
security definer
set search_path = public
as $$
declare
  uid      uuid := auth.uid();
  updated  public.patients;
begin
  if uid is null then
    raise exception 'You need to be signed in.';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'A name is required.';
  end if;

  update public.patients
  set name          = trim(p_name),
      phone         = coalesce(trim(p_phone), ''),
      date_of_birth = p_date_of_birth,
      gender        = coalesce(p_gender, ''),
      height_cm     = p_height_cm,
      weight_kg     = p_weight_kg
  where user_id = uid
  returning * into updated;

  if updated.id is null then
    raise exception 'Your patient record could not be found.';
  end if;

  return updated;
end;
$$;

grant execute on function public.update_patient_profile(text, text, date, text, numeric, numeric) to authenticated;
