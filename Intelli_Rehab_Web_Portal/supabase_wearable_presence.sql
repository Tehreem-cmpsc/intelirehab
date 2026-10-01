-- Live wearable connectivity.
--
-- Until now the portal's "Wearable connected" meant only "a wearable_devices
-- row with status = 'paired' exists" - i.e. it had been paired once, not that
-- it is connected now. This adds real presence:
--
--   * the patient's phone calls report_wearable_presence(true) every ~15 s
--     while its Bluetooth link to the band is up, and (false) when it drops;
--   * get_wearable_presence() tells the portal which patients are live RIGHT
--     NOW. "Live" = reported connected AND heard from in the last 45 s, so a
--     phone that dies or loses signal without saying goodbye expires on its
--     own. The comparison uses the database clock, never the browser's.
--   * wearable_devices is added to the realtime publication so the portal can
--     refresh the moment a change happens (RLS still decides who may see it).
--
-- Run after supabase_full_schema_snapshot.sql. Idempotent.

alter table public.wearable_devices
  add column if not exists is_connected boolean not null default false,
  add column if not exists last_seen_at timestamptz;

-- Called by the patient's own phone. Scoped to the caller's current band.
create or replace function public.report_wearable_presence(p_connected boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.wearable_devices d
     set is_connected = p_connected,
         last_seen_at = now()
   where d.status = 'paired'
     and d.patient_id in (select p.id from public.patients p where p.user_id = auth.uid());
end;
$$;

revoke all on function public.report_wearable_presence(boolean) from public, anon;
grant execute on function public.report_wearable_presence(boolean) to authenticated;

-- SECURITY INVOKER: runs as the physio/admin, so wearable_devices' existing
-- RLS limits the rows to their own clinic's patients.
create or replace function public.get_wearable_presence()
returns table (patient_id uuid, is_live boolean, last_seen_at timestamptz)
language sql
stable
as $$
  select d.patient_id,
         (d.is_connected and d.last_seen_at > now() - interval '45 seconds') as is_live,
         d.last_seen_at
  from public.wearable_devices d
  where d.status = 'paired';
$$;

revoke all on function public.get_wearable_presence() from public, anon;
grant execute on function public.get_wearable_presence() to authenticated;

-- Realtime: broadcast changes to wearable_devices (guarded: adding a table
-- that is already published is an error).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'wearable_devices'
  ) then
    alter publication supabase_realtime add table public.wearable_devices;
  end if;
end $$;
