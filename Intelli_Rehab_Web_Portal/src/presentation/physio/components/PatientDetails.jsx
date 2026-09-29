import { THEME } from "../../../infrastructure/physio/constants";
import useIsMobile from "../../useIsMobile";
import {
  ageFrom,
  formatDate,
  genderLabel,
  activityLabel,
  armLabel,
  jointLabel,
  injuryTypeLabel,
  causeLabel,
  painLabel,
} from "../../../domain/physio/utils/patientLabels";

// Who the patient picked during onboarding. Physios can only read their own
// physiotherapists row under RLS, so a colleague is shown generically.
export function chosenPhysioLabel(patient, currentPhysioId) {
  const id = patient.profile.physioId;
  if (!id) return "Not chosen yet";
  return id === currentPhysioId ? "You" : "Another physio at your clinic";
}

// Everything the patient entered in the mobile app's onboarding, grouped
// the way the app asks for it.
function PatientDetails({ patient, currentPhysioId }) {
  const isMobile = useIsMobile();
  const { profile, injuryDetails: injury, device, baseline } = patient;
  const age = ageFrom(profile.dateOfBirth);
  const yesNo = (v) => (v == null ? null : v ? "Yes" : "No");

  const groups = [
    {
      title: "About",
      rows: [
        ["Date of birth", profile.dateOfBirth && `${formatDate(profile.dateOfBirth)}${age != null ? ` (${age})` : ""}`],
        ["Gender", genderLabel(profile.gender)],
        ["Activity level", activityLabel(profile.activityLevel)],
        ["Dominant arm", armLabel(profile.dominantArm)],
      ],
    },
    {
      title: "Contact",
      rows: [
        ["Email", profile.email],
        ["Phone", profile.phone],
        ["Registered", formatDate(profile.registeredAt)],
      ],
    },
    {
      title: "Injury",
      rows: [
        [
          "Area",
          injury && [injury.side && `${armLabel(injury.side)} arm`, jointLabel(injury.joint)].filter(Boolean).join(" · "),
        ],
        ["Type", injuryTypeLabel(injury?.type)],
        ["Cause", causeLabel(injury?.cause)],
        ["Date of injury", formatDate(injury?.date)],
        ["First injury", yesNo(injury?.firstInjury)],
        ["Pain level", painLabel(injury?.painLevel)],
        ["Notes", injury?.notes],
      ],
    },
    {
      title: "Setup",
      rows: [
        ["Physiotherapist", chosenPhysioLabel(patient, currentPhysioId)],
        ["Wearable", device ? [device.serial, device.firmware && `fw ${device.firmware}`].filter(Boolean).join(" · ") : "Not paired"],
        [
          "Baseline",
          baseline
            ? `${Math.round(baseline.flexion)}° flexion · ${Math.round(baseline.range)}° range`
            : "Not calibrated",
        ],
        ["Baseline taken", formatDate(baseline?.recordedAt)],
      ],
    },
  ];

  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: isMobile ? "minmax(0, 1fr)" : "repeat(auto-fit, minmax(220px, 1fr))",
        gap: isMobile ? 14 : 18,
      }}
    >
      {groups.map((g) => (
        <div key={g.title} style={{ minWidth: 0 }}>
          <div
            style={{
              fontSize: 11,
              fontWeight: 700,
              color: THEME.slate400,
              textTransform: "uppercase",
              letterSpacing: 0.6,
              marginBottom: 8,
            }}
          >
            {g.title}
          </div>
          {g.rows
            .filter(([, v]) => v)
            .map(([label, value]) => (
              <div key={label} style={{ display: "flex", gap: 10, fontSize: 13, padding: "4px 0" }}>
                <span style={{ color: THEME.slate500, flex: "0 0 110px" }}>{label}</span>
                <span style={{ color: THEME.slate800, fontWeight: 600, minWidth: 0, overflowWrap: "anywhere" }}>
                  {value}
                </span>
              </div>
            ))}
        </div>
      ))}
    </div>
  );
}

export default PatientDetails;
