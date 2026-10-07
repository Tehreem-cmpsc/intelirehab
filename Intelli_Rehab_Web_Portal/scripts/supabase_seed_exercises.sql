-- Seeds the `exercises` table (the physiotherapist's Exercise Database tab
-- and the assign-session picker both read it). 35 dummy upper-limb
-- rehabilitation exercises covering shoulder, scapula, elbow, forearm/wrist
-- and hand/grip, across Beginner / Intermediate / Advanced.
--
-- Generated from data/exercises.csv - edit the CSV and regenerate rather than
-- hand-editing this file. Dummy/demo content: have a clinician review the
-- descriptions before real patients are given these exercises.
--
-- Idempotent via a NOT EXISTS check on name (there's no unique constraint
-- on that column) - safe to run more than once without duplicating rows.

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
  ('Isometric Bicep Hold', 'Bicep (isometric)', 'Beginner', 'Static contraction hold to activate muscle without joint stress.'),
  ('Shoulder Flexion Raise', 'Anterior deltoid', 'Beginner', 'Raise the arm forward to shoulder height with the thumb up, then lower slowly.'),
  ('Shoulder Internal Rotation', 'Subscapularis', 'Intermediate', 'Elbow at side bent to 90 degrees, rotate the forearm across the body against light resistance.'),
  ('Wall Slide', 'Serratus anterior / Deltoid', 'Beginner', 'Forearms on a wall, slide upward as far as comfortable to regain overhead range.'),
  ('Table Slide', 'Shoulder capsule', 'Beginner', 'Seated, slide the hand forward across a table to gently increase shoulder flexion range.'),
  ('Shoulder Shrug', 'Upper trapezius', 'Beginner', 'Lift the shoulders toward the ears, hold briefly, and lower with control.'),
  ('Full Can Raise', 'Supraspinatus', 'Intermediate', 'Raise the arms in the scapular plane with thumbs up to strengthen the supraspinatus.'),
  ('Shoulder Horizontal Abduction', 'Posterior deltoid / Rhomboids', 'Intermediate', 'Lying face down, lift the arm out to the side to strengthen the back of the shoulder.'),
  ('Cross-Body Shoulder Stretch', 'Posterior capsule', 'Beginner', 'Draw the arm across the chest with the other hand to stretch the back of the shoulder.'),
  ('Wall Push-Up Plus', 'Serratus anterior', 'Intermediate', 'Wall push-up finishing with a small extra push to protract the shoulder blades.'),
  ('Overhead Resistance Band Press', 'Deltoid / Triceps', 'Advanced', 'Press a resistance band overhead from shoulder height to build functional overhead strength.'),
  ('Scapular Squeeze Hold', 'Rhomboids / Mid trapezius', 'Beginner', 'Draw the shoulder blades together and hold for five seconds, keeping the neck relaxed.'),
  ('Prone Y Raise', 'Lower trapezius', 'Advanced', 'Lying face down, lift the arms in a Y shape to strengthen the lower trapezius.'),
  ('Band Pull-Apart', 'Posterior deltoid / Rhomboids', 'Intermediate', 'Hold a resistance band at chest height and pull the hands apart, squeezing the shoulder blades.'),
  ('Elbow Extension with Band', 'Triceps', 'Intermediate', 'Anchored resistance band, straighten the elbow against tension and return slowly.'),
  ('Hammer Curl', 'Brachioradialis / Bicep', 'Intermediate', 'Curl a light weight with the palm facing inward to strengthen the forearm and elbow flexors.'),
  ('Active Assisted Elbow Flexion', 'Elbow flexors', 'Beginner', 'Use the other hand to help bend the injured elbow through its available range.'),
  ('Towel Elbow Stretch', 'Elbow flexors / extensors', 'Beginner', 'Hold a towel with both hands and gently stretch to restore full elbow extension.'),
  ('Eccentric Bicep Lowering', 'Bicep (eccentric)', 'Advanced', 'Lift a light weight with both hands, then lower it slowly with the injured arm alone.'),
  ('Wrist Extension Curl', 'Wrist extensors', 'Beginner', 'Forearm supported, palm down, lift the hand upward against light resistance.'),
  ('Radial & Ulnar Deviation', 'Wrist deviators', 'Beginner', 'Move the wrist side to side in a hammer-like motion to restore wrist stability.'),
  ('Wrist Circles', 'Wrist joint', 'Beginner', 'Slow controlled circles of the wrist in both directions to improve mobility.'),
  ('Reverse Wrist Curl', 'Wrist extensors', 'Intermediate', 'Palm-down wrist curl with a light weight to strengthen the extensor group.'),
  ('Wrist Flexor Stretch', 'Wrist flexors', 'Beginner', 'Extend the arm palm up and gently pull the fingers back to stretch the forearm.'),
  ('Putty Squeeze', 'Grip muscles', 'Beginner', 'Squeeze therapy putty with the whole hand and release slowly to rebuild grip strength.'),
  ('Finger Tendon Glides', 'Finger flexors', 'Beginner', 'Move the fingers through a sequence of hook, fist and straight positions to keep tendons gliding.'),
  ('Pinch Strengthening', 'Thumb / Finger muscles', 'Intermediate', 'Pinch putty or a soft ball between the thumb and each fingertip in turn.'),
  ('Towel Wring', 'Forearm / Grip', 'Intermediate', 'Wring a towel with both hands, twisting in opposite directions to train grip and forearm rotation.')
) as v(name, target, difficulty, description)
where not exists (
  select 1 from public.exercises e where e.name = v.name
);
