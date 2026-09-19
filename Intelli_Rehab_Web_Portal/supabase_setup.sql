-- ============================================================
-- FULL RESET of clinics + physiotherapists (run in SQL Editor)
-- ⚠️ THIS DELETES ALL EXISTING CLINIC AND PHYSIOTHERAPIST ROWS.
-- `patients` is intentionally left untouched.
-- ============================================================

-- --- 0. BEFORE running this: delete old logins ---------------
-- Go to Authentication → Users in the dashboard and delete any
-- existing clinic-admin / physiotherapist accounts. Their rows
-- below are about to disappear, so those logins would otherwise
-- be orphaned (an Auth user with no matching clinic/physio row).

create extension if not exists pgcrypto;

-- --- 1. Drop old tables (and everything attached to them) ----
drop table if exists public.physiotherapists cascade;
drop table if exists public.clinics cascade;

-- --- 2. Recreate clean schema ----------------------------------
create table public.clinics (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name       text not null,
  email      text not null unique,
  phone      text,
  address    text,
  logo_url   text
);

create table public.physiotherapists (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  clinic_id        uuid not null references public.clinics(id) on delete cascade,
  user_id          uuid not null references auth.users(id) on delete cascade,
  physio_code      text not null unique,
  full_name        text,
  specialization   text,
  license_number   text,
  status           text not null default 'Active'
);

-- --- 3. Turn on RLS ---------------------------------------------
alter table public.clinics enable row level security;
alter table public.physiotherapists enable row level security;

-- --- 4. clinics policies ------------------------------------------
-- A clinic admin can see/update the clinic row matching their own login email.
create policy "Admins can view their own clinic"
  on public.clinics for select
  using (email = auth.email());

create policy "Admins can update their own clinic"
  on public.clinics for update
  using (email = auth.email())
  with check (email = auth.email());

-- A physiotherapist can see the clinic they belong to (needed for the
-- `select("*, clinics(*)")` join in useAuth.js).
create policy "Physios can view their own clinic"
  on public.clinics for select
  using (
    exists (
      select 1 from public.physiotherapists p
      where p.clinic_id = clinics.id
        and p.user_id = auth.uid()
    )
  );

-- --- 5. physiotherapists policies ----------------------------------
-- A physiotherapist can see their own profile row.
create policy "Physios can view their own profile"
  on public.physiotherapists for select
  using (user_id = auth.uid());

-- A clinic admin can view/add/remove physiotherapists in their own clinic.
create policy "Admins can view their clinic physiotherapists"
  on public.physiotherapists for select
  using (
    exists (
      select 1 from public.clinics c
      where c.id = physiotherapists.clinic_id
        and c.email = auth.email()
    )
  );

create policy "Admins can add physiotherapists to their clinic"
  on public.physiotherapists for insert
  with check (
    exists (
      select 1 from public.clinics c
      where c.id = physiotherapists.clinic_id
        and c.email = auth.email()
    )
  );

create policy "Admins can remove physiotherapists from their clinic"
  on public.physiotherapists for delete
  using (
    exists (
      select 1 from public.clinics c
      where c.id = physiotherapists.clinic_id
        and c.email = auth.email()
    )
  );

-- --- 6. Recreate the login lookup function ---------------------------
-- Used by the login page to turn a typed Physiotherapist ID into the
-- email Supabase Auth needs. SECURITY DEFINER lets it read auth.users
-- (which normal client roles can't) and bypass physiotherapists RLS,
-- since this runs BEFORE the user is signed in.
create or replace function public.get_physio_email(physio_code text)
returns text
language sql
security definer
set search_path = public
as $$
  select au.email
  from public.physiotherapists p
  join auth.users au on au.id = p.user_id
  where p.physio_code = get_physio_email.physio_code
  limit 1;
$$;

grant execute on function public.get_physio_email(text) to anon, authenticated;
