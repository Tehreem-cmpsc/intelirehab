-- Adds credentialing fields + lets admins update (approve) physiotherapists.
-- Safe to run any time — does NOT touch existing rows' data (new columns
-- come back null for existing rows).

alter table public.physiotherapists
  add column if not exists cnic text,
  add column if not exists qualification text,
  add column if not exists years_experience integer,
  add column if not exists joining_date date;

-- There was no UPDATE policy yet — needed so an admin can flip a
-- physiotherapist's status from 'Pending' to 'Active'.
drop policy if exists "Admins can update their clinic physiotherapists" on public.physiotherapists;
create policy "Admins can update their clinic physiotherapists"
  on public.physiotherapists for update
  using (public.is_admin_of_clinic(clinic_id))
  with check (public.is_admin_of_clinic(clinic_id));
