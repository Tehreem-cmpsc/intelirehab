-- Seeds the real `exercises` table with the same 8 exercises currently
-- hardcoded in src/infrastructure/physio/constants/mockData.js — the
-- physio Exercise Database tab still reads that mock array, not this
-- table, since nothing queries `exercises` from Supabase yet. This just
-- gives the table real starting data for whenever that gets wired up.
--
-- Idempotent via a NOT EXISTS check on name (there's no unique constraint
-- on that column) — safe to run more than once without duplicating rows.

insert into public.exercises (name, target, difficulty, description)
select v.name, v.target, v.difficulty, v.description
from (values
  ('Elbow Flexion & Extension', 'Bicep / Tricep', 'Beginner', 'Controlled full-arc elbow bend to strengthen bicep and tricep.'),
  ('Shoulder External Rotation', 'Rotator Cuff', 'Intermediate', 'Outward rotation against resistance to restore shoulder stability.'),
  ('Forearm Supination/Pronation', 'Forearm muscles', 'Beginner', 'Twisting forearm palm-up and palm-down to restore pronation range.'),
  ('Shoulder Abduction Raise', 'Deltoid / Supraspinatus', 'Intermediate', 'Lateral arm raise to 90 degrees targeting deltoid recovery.'),
  ('Wrist Flexion Curl', 'Wrist flexors', 'Beginner', 'Gentle wrist curl to rebuild grip and flexor strength post-cast.'),
  ('Scapular Retraction', 'Rhomboids / Traps', 'Advanced', 'Squeeze shoulder blades together for upper-back posture correction.'),
  ('Pendulum Arm Swing', 'Shoulder capsule', 'Beginner', 'Passive gravitational swing to decompress the shoulder joint.'),
  ('Isometric Bicep Hold', 'Bicep (isometric)', 'Beginner', 'Static contraction hold to activate muscle without joint stress.')
) as v(name, target, difficulty, description)
where not exists (
  select 1 from public.exercises e where e.name = v.name
);
