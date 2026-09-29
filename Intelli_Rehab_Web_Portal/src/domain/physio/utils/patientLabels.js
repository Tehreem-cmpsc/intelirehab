// Display labels for the answers a patient gives during mobile onboarding.
// Keys match the check constraints in supabase_patient_onboarding*.sql
// (v1 values are kept so older rows still read properly).

const GENDER = {
  male: "Male",
  female: "Female",
  other: "Other",
  prefer_not_to_say: "Prefer not to say",
};

const ACTIVITY = {
  sedentary: "Sedentary",
  light: "Light",
  active: "Active",
  very_active: "Very active",
};

const ARM = { left: "Left", right: "Right", both: "Both" };

const JOINT = {
  upper_arm: "Upper arm",
  elbow: "Elbow",
  forearm: "Forearm",
  shoulder: "Shoulder",
  wrist: "Wrist",
  multiple: "More than one area",
};

const INJURY_TYPE = {
  muscle_strain: "Muscle strain",
  tendon: "Tendon",
  joint: "Joint",
  fracture: "Fracture",
  post_surgery: "After surgery",
  other: "Other / not sure",
  sprain_strain: "Sprain / strain",
  dislocation: "Dislocation",
  stiffness: "Stiffness",
  not_sure: "Not sure",
};

const CAUSE = {
  sports: "Sports",
  fall: "A fall",
  accident: "Accident",
  overuse: "Overuse",
  surgery: "Surgery",
  other: "Other",
};

const PAIN = ["None", "Mild", "Moderate", "Severe"];

const pick = (map, value) => (value ? map[value] ?? value : null);

export const genderLabel = (v) => pick(GENDER, v);
export const activityLabel = (v) => pick(ACTIVITY, v);
export const armLabel = (v) => pick(ARM, v);
export const jointLabel = (v) => pick(JOINT, v);
export const injuryTypeLabel = (v) => pick(INJURY_TYPE, v);
export const causeLabel = (v) => pick(CAUSE, v);
export const painLabel = (v) => (v == null ? null : `${PAIN[v] ?? v} (${v}/3)`);

export function ageFrom(dateOfBirth) {
  if (!dateOfBirth) return null;
  const dob = new Date(dateOfBirth);
  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  if (now < new Date(now.getFullYear(), dob.getMonth(), dob.getDate())) age -= 1;
  return age;
}

export function formatDate(value) {
  if (!value) return null;
  return new Date(value).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}
