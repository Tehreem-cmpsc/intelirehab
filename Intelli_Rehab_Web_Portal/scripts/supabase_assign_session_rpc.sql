-- Assigning an exercise session as ONE transaction.
-- Previously the portal made 5-6 separate calls, ignored errors on the
-- "retire the old plan" steps, and could leave two active plans.
--
-- SECURITY INVOKER (the default): runs as the calling physio, so the
-- existing RLS policies on rehabilitation_plans / patient_exercise_plans
-- still decide whether they may do this for this patient.
--
-- p_start_date comes from the browser's local calendar date (the server
-- clock is UTC, which is the wrong day for part of every day in Pakistan).
-- Run after the core tables / rehabilitation_plan_fields scripts.

create or replace function public.assign_exercise_session(
  p_patient_id uuid,
  p_physio_id  uuid,
  p_plan_name  text,
  p_start_date date,
  p_exercises  jsonb  -- [{exerciseId, sets, reps, romTarget, frequency}, ...]
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

  -- Retire what is active now.
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
    (patient_id, exercise_id, assigned_by, plan_id, sets, reps, rom_target, frequency, active)
  select p_patient_id,
         (e->>'exerciseId')::uuid,
         p_physio_id,
         new_plan_id,
         (e->>'sets')::int,
         (e->>'reps')::int,
         nullif(e->>'romTarget', '')::int,
         e->>'frequency',
         true
  from jsonb_array_elements(p_exercises) as e;

  return new_plan_id;
end;
$$;

revoke all on function public.assign_exercise_session(uuid, uuid, text, date, jsonb) from public, anon;
grant execute on function public.assign_exercise_session(uuid, uuid, text, date, jsonb) to authenticated;
