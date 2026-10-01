-- Security hardening before deployment. Run once, after every other script.
-- Idempotent. Does not delete row data.
--
-- 1. Physios can no longer edit their own row (status / clinic_id escalation).
-- 2. Staff access requires an *Active* physiotherapist, enforced in the
--    database, not just the login screen.
-- 3. Clinic admins are bound to an auth user id, not to an email address
--    anyone could sign up with.
-- 4. get_physio_email() is no longer callable by clients (user enumeration);
--    the physio-auth Edge Function does the lookup server-side.

-- ---------------------------------------------------------------
-- 1. Physio self-update: remove the open policy, offer one narrow RPC.
-- ---------------------------------------------------------------
drop policy if exists "Physios can update their own profile" on public.physiotherapists;

create or replace function public.complete_first_login_reset()
returns void
language sql
security definer
set search_path = public
as $$
  update public.physiotherapists
  set must_reset_password = false
  where user_id = auth.uid();
$$;

revoke all on function public.complete_first_login_reset() from public, anon;
grant execute on function public.complete_first_login_reset() to authenticated;

-- ---------------------------------------------------------------
-- 2. Only Active physios count as clinic staff.
--    (Pending / Rejected physios can still read their own profile row, which
--    the portal needs to tell them why they can't continue.)
-- ---------------------------------------------------------------
create or replace function public.is_physio_of_clinic(target_clinic_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.physiotherapists p
    where p.clinic_id = target_clinic_id
      and p.user_id = auth.uid()
      and p.status = 'Active'
  );
$$;

-- ---------------------------------------------------------------
-- 3. Admin identity = auth user id.
-- ---------------------------------------------------------------
alter table public.clinics
  add column if not exists admin_user_id uuid references auth.users(id) on delete set null;

-- Backfill only from *confirmed* emails, so an unconfirmed sign-up can't
-- be adopted as the admin.
update public.clinics c
set admin_user_id = u.id
from auth.users u
where c.admin_user_id is null
  and lower(u.email) = lower(c.email)
  and u.email_confirmed_at is not null;

create or replace function public.is_admin_of_clinic(target_clinic_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.clinics c
    where c.id = target_clinic_id
      and c.admin_user_id = auth.uid()
  );
$$;

drop policy if exists "Admins can view their own clinic" on public.clinics;
create policy "Admins can view their own clinic"
  on public.clinics for select
  using (admin_user_id = auth.uid());

drop policy if exists "Admins can update their own clinic" on public.clinics;
create policy "Admins can update their own clinic"
  on public.clinics for update
  using (admin_user_id = auth.uid())
  with check (admin_user_id = auth.uid());

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
     or exists (select 1 from public.clinics where admin_user_id = uid) then
    raise exception 'Staff accounts are deleted from the web portal.';
  end if;

  delete from public.patients where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Check: every clinic must now have an admin, or nobody can manage it.
-- select id, name, email from public.clinics where admin_user_id is null;

-- ---------------------------------------------------------------
-- 4. No client-side physio-code -> email lookup.
-- ---------------------------------------------------------------
revoke execute on function public.get_physio_email(text) from public, anon, authenticated;

-- ---------------------------------------------------------------
-- 5. Throttle for the physio-auth Edge Function (per physio ID).
--    RLS on with no policies: only the service role can touch it.
-- ---------------------------------------------------------------
create table if not exists public.physio_auth_attempts (
  physio_code  text        not null,
  attempted_at timestamptz not null default now()
);
create index if not exists physio_auth_attempts_lookup
  on public.physio_auth_attempts (physio_code, attempted_at desc);
alter table public.physio_auth_attempts enable row level security;
revoke all on public.physio_auth_attempts from anon, authenticated;
