-- Keeps patients.wearable_connected in step with wearable_devices, so the
-- web portal's wearable column (PatientUseCases.js reads
-- row.wearable_connected) reflects a band the patient paired in the
-- mobile app. Run after supabase_full_schema_snapshot.sql.
--
-- The mobile app writes wearable_devices through its existing "own
-- patient" RLS policy (status = 'paired' for the current band,
-- 'replaced' for older ones). Patients deliberately have no UPDATE
-- policy on patients (see supabase_patient_self_registration.sql), so the
-- app can't set the flag itself — this SECURITY DEFINER trigger does,
-- touching only that one column.
--
-- Safe to run any time — idempotent.

create or replace function public.sync_patient_wearable_connected()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  if tg_op = 'DELETE' then
    target := old.patient_id;
  else
    target := new.patient_id;
  end if;

  update public.patients p
  set wearable_connected = exists (
    select 1 from public.wearable_devices d
    where d.patient_id = target and d.status = 'paired'
  )
  where p.id = target;

  -- A device moved to another patient: refresh the old owner too.
  if tg_op = 'UPDATE' and old.patient_id is distinct from new.patient_id then
    update public.patients p
    set wearable_connected = exists (
      select 1 from public.wearable_devices d
      where d.patient_id = old.patient_id and d.status = 'paired'
    )
    where p.id = old.patient_id;
  end if;

  return null;
end;
$$;

drop trigger if exists wearable_devices_sync_patient on public.wearable_devices;
create trigger wearable_devices_sync_patient
  after insert or delete or update of status, patient_id on public.wearable_devices
  for each row execute function public.sync_patient_wearable_connected();

-- Backfill rows paired before this trigger existed.
update public.patients p
set wearable_connected = exists (
  select 1 from public.wearable_devices d
  where d.patient_id = p.id and d.status = 'paired'
)
where p.wearable_connected is distinct from exists (
  select 1 from public.wearable_devices d
  where d.patient_id = p.id and d.status = 'paired'
);
