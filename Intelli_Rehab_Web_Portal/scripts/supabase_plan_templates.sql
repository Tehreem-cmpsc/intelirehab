-- Reusable exercise plans: a physiotherapist saves what they just assigned as a template ("Post-fracture
-- elbow, weeks 1-2") and assigns it to the next patient in one click, instead of building the same plan
-- from scratch each time.
--
-- Templates belong to a clinic and are shared by its physiotherapists (and visible to its administrator).
-- `exercises` is the list the assign form sends to assign_exercise_session:
--   [{ "exerciseId": "...", "sets": 3, "reps": 10, "romTarget": 70, "frequency": "Daily", "restSeconds": 30 }]
-- It is kept as JSON so a template is exactly what was assigned; exercises that have since been removed from
-- the catalogue are simply left out when a template is applied (the portal tells the physio).
--
-- Run after supabase_core_tables.sql. Safe to run any time - idempotent.

create table if not exists public.plan_templates (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  clinic_id   uuid not null references public.clinics(id) on delete cascade,
  created_by  uuid references public.physiotherapists(id) on delete set null,
  name        text not null,
  exercises   jsonb not null,
  constraint plan_templates_name_check check (char_length(btrim(name)) between 1 and 60),
  constraint plan_templates_exercises_check
    check (jsonb_typeof(exercises) = 'array' and jsonb_array_length(exercises) between 1 and 20)
);

-- One name per clinic, ignoring case, so the list never shows two identical entries.
create unique index if not exists plan_templates_clinic_name_idx
  on public.plan_templates (clinic_id, lower(btrim(name)));

alter table public.plan_templates enable row level security;

drop policy if exists "Clinic staff can view plan templates" on public.plan_templates;
create policy "Clinic staff can view plan templates"
  on public.plan_templates for select
  using (public.is_physio_of_clinic(clinic_id) or public.is_admin_of_clinic(clinic_id));

drop policy if exists "Physiotherapists can add plan templates" on public.plan_templates;
create policy "Physiotherapists can add plan templates"
  on public.plan_templates for insert
  with check (public.is_physio_of_clinic(clinic_id));

drop policy if exists "Clinic staff can remove plan templates" on public.plan_templates;
create policy "Clinic staff can remove plan templates"
  on public.plan_templates for delete
  using (public.is_physio_of_clinic(clinic_id) or public.is_admin_of_clinic(clinic_id));

grant select, insert, delete on public.plan_templates to authenticated;
