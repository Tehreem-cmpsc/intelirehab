-- Fixes: 42P17 "infinite recursion detected in policy"
-- Cause: the clinics policy queries physiotherapists, and the
-- physiotherapists policy queries clinics right back — each triggers
-- the other's RLS evaluation, forever.
--
-- Fix: move the cross-table checks into SECURITY DEFINER functions.
-- These run as their owner (postgres), who owns the tables and so
-- bypasses RLS on them — breaking the recursive loop.
--
-- Safe to run any time — does NOT touch table data.

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
      and c.email = auth.email()
  );
$$;

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
  );
$$;

-- --- clinics: replace the policy that queried physiotherapists ---
drop policy if exists "Physios can view their own clinic" on public.clinics;
create policy "Physios can view their own clinic"
  on public.clinics for select
  using (public.is_physio_of_clinic(id));

-- --- physiotherapists: replace the policies that queried clinics ---
drop policy if exists "Admins can view their clinic physiotherapists" on public.physiotherapists;
create policy "Admins can view their clinic physiotherapists"
  on public.physiotherapists for select
  using (public.is_admin_of_clinic(clinic_id));

drop policy if exists "Admins can add physiotherapists to their clinic" on public.physiotherapists;
create policy "Admins can add physiotherapists to their clinic"
  on public.physiotherapists for insert
  with check (public.is_admin_of_clinic(clinic_id));

drop policy if exists "Admins can remove physiotherapists from their clinic" on public.physiotherapists;
create policy "Admins can remove physiotherapists from their clinic"
  on public.physiotherapists for delete
  using (public.is_admin_of_clinic(clinic_id));

-- "Admins can view their own clinic" / "Admins can update their own clinic"
-- (email = auth.email()) and "Physios can view their own profile"
-- (user_id = auth.uid()) were never recursive — left untouched.
