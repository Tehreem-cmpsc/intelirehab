import { Exercise } from "../../../domain/physio/entities";

// The physio Exercise Database tab still reads this — exercises aren't
// wired to the real `exercises` Supabase table yet (see
// supabase_seed_exercises.sql, which seeds that table with the same 8
// exercises for whenever that wiring happens).
export const EXERCISES = [
  new Exercise({
    id: 1,
    name: "Elbow Flexion & Extension",
    target: "Bicep / Tricep",
    difficulty: "Beginner",
    desc: "Controlled full-arc elbow bend to strengthen bicep and tricep.",
  }),
  new Exercise({
    id: 2,
    name: "Shoulder External Rotation",
    target: "Rotator Cuff",
    difficulty: "Intermediate",
    desc: "Outward rotation against resistance to restore shoulder stability.",
  }),
  new Exercise({
    id: 3,
    name: "Forearm Supination/Pronation",
    target: "Forearm muscles",
    difficulty: "Beginner",
    desc: "Twisting forearm palm-up and palm-down to restore pronation range.",
  }),
  new Exercise({
    id: 4,
    name: "Shoulder Abduction Raise",
    target: "Deltoid / Supraspinatus",
    difficulty: "Intermediate",
    desc: "Lateral arm raise to 90° targeting deltoid recovery.",
  }),
  new Exercise({
    id: 5,
    name: "Wrist Flexion Curl",
    target: "Wrist flexors",
    difficulty: "Beginner",
    desc: "Gentle wrist curl to rebuild grip and flexor strength post-cast.",
  }),
  new Exercise({
    id: 6,
    name: "Scapular Retraction",
    target: "Rhomboids / Traps",
    difficulty: "Advanced",
    desc: "Squeeze shoulder blades together for upper-back posture correction.",
  }),
  new Exercise({
    id: 7,
    name: "Pendulum Arm Swing",
    target: "Shoulder capsule",
    difficulty: "Beginner",
    desc: "Passive gravitational swing to decompress the shoulder joint.",
  }),
  new Exercise({
    id: 8,
    name: "Isometric Bicep Hold",
    target: "Bicep (isometric)",
    difficulty: "Beginner",
    desc: "Static contraction hold to activate muscle without joint stress.",
  }),
];
