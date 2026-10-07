-- Patient self-registration (FR-1): lets the mobile app attach a patient's
-- own login to a patient record a physio already created.
--
-- Mirrors the physio onboarding pattern already in this repo: a physio
-- creates the `patients` row (name, injury, clinic_id, reg_id — the
-- patient-side equivalent of physio_code), hands the patient their reg_id,
-- and the patient uses it once in the mobile app to link their own
-- Supabase Auth account. The row stays `approved = false` until a physio
-- approves them via the existing ApprovalsPage.jsx flow — no change needed
-- there, it already filters on `approved`.
--
-- This intentionally does NOT add a raw `UPDATE` RLS policy for patients
-- on their own `user_id` — that would let a signed-in patient overwrite
-- any column on any row they could guess a reg_id for. A SECURITY DEFINER
-- function scoped to exactly one column, one row, one time, is safer.
--
-- Safe to run any time — idempotent.

create or replace function public.claim_patient_record(target_reg_id text)
returns public.patients
language plpgsql
security definer
set search_path = public
as $$
declare
  claimed public.patients;
begin
  if target_reg_id is null or length(trim(target_reg_id)) = 0 then
    raise exception 'A registration ID is required.';
  end if;

  update public.patients
  set user_id = auth.uid()
  where reg_id = target_reg_id
    and user_id is null
  returning * into claimed;

  if claimed.id is null then
    raise exception 'That registration ID is invalid or has already been claimed.';
  end if;

  return claimed;
end;
$$;

grant execute on function public.claim_patient_record(text) to authenticated;
