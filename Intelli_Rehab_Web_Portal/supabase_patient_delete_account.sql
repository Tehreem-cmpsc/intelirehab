-- Patient self-service account deletion (Google Play's account-deletion
-- policy: an app that lets people create an account must let them delete
-- it from inside the app).
--
-- delete_my_account() — SECURITY DEFINER, scoped to exactly the caller:
--   1. deletes their patients row; patient_injuries, sessions,
--      rehabilitation_plans, patient_exercise_plans, wearable_devices,
--      patient_badges … all reference patients(id) ON DELETE CASCADE;
--   2. deletes their auth.users login.
-- Refuses for staff logins (physiotherapists / clinic admins), whose
-- accounts are managed from the web portal instead.
--
-- Safe to run any time — idempotent.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'You need to be signed in to delete your account.';
  end if;

  if exists (select 1 from public.physiotherapists where user_id = uid)
     or exists (select 1 from public.clinics where email = auth.email()) then
    raise exception 'Staff accounts are deleted from the web portal.';
  end if;

  delete from public.patients where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
