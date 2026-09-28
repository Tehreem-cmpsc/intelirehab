-- Patient onboarding, Step 2 of 4 (SRS UC-2 + UC-3 on one screen): choose a
-- clinic, then a physiotherapist at that clinic. Run after
-- supabase_patient_onboarding.sql.
--
-- Patients can't read `clinics` or `physiotherapists` under the existing RLS
-- (those policies are for clinic staff), and shouldn't: those rows hold
-- emails, CNICs and licence numbers. So, as with register_patient_self, these
-- are SECURITY DEFINER functions exposing only what the screen shows:
--
--   list_onboarding_clinics()             every clinic: id, name, address
--   list_clinic_physiotherapists(clinic)  Active physios at that clinic: id,
--                                         name, specialisation, years' experience
--   choose_clinic_and_physio(clinic, physio)
--                                         sets the caller's own clinic_id and
--                                         physio_id together — only to an
--                                         Active physio at that clinic, and only
--                                         while the patient is still unapproved
--
-- Safe to run any time — idempotent. Also drops the four functions from the
-- earlier two-screen draft (supabase_patient_choose_physio.sql), if they were
-- ever created.

drop function if exists public.my_onboarding_clinic();
drop function if exists public.list_my_clinic_physiotherapists();
drop function if exists public.choose_physiotherapist(uuid);
drop function if exists public.clear_clinic_choice();

create or replace function public.list_onboarding_clinics()
returns table (id uuid, name text, address text)
language sql
security definer
set search_path = public
stable
as $$
  select c.id, c.name, c.address
  from public.clinics c
  where auth.uid() is not null
  order by c.name;
$$;

create or replace function public.list_clinic_physiotherapists(p_clinic_id uuid)
returns table (id uuid, full_name text, specialization text, years_experience integer)
language sql
security definer
set search_path = public
stable
as $$
  select ph.id, ph.full_name, ph.specialization, ph.years_experience
  from public.physiotherapists ph
  where auth.uid() is not null
    and ph.clinic_id = p_clinic_id
    and ph.status = 'Active'
  order by ph.full_name;
$$;

create or replace function public.choose_clinic_and_physio(p_clinic_id uuid, p_physio_id uuid)
returns public.patients
language plpgsql
security definer
set search_path = public
as $$
declare
  updated public.patients;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in.';
  end if;

  if not exists (
    select 1 from public.physiotherapists ph
    where ph.id = p_physio_id
      and ph.clinic_id = p_clinic_id
      and ph.status = 'Active'
  ) then
    raise exception 'That physiotherapist is not available at this clinic.';
  end if;

  update public.patients
  set clinic_id = p_clinic_id, physio_id = p_physio_id
  where user_id = auth.uid()
    and approved = false
  returning * into updated;

  if updated.id is null then
    raise exception 'Your clinic can no longer be changed from the app. Contact your clinic.';
  end if;

  return updated;
end;
$$;

grant execute on function public.list_onboarding_clinics() to authenticated;
grant execute on function public.list_clinic_physiotherapists(uuid) to authenticated;
grant execute on function public.choose_clinic_and_physio(uuid, uuid) to authenticated;
