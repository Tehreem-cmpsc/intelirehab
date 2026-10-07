import { THEME } from "../../../infrastructure/physio/constants";
import Card from "./Card";
import { FOLLOW_UP_DAYS, ageLabel, daysSince } from "../../../domain/physio/utils/warnings";

// Whether the patient tapped "Got it" on the warning in their app. `receipts` maps patientId -> Date | null;
// a patient missing from it just has no receipt yet.
export function SeenBadge({ readAt }) {
  const seen = Boolean(readAt);
  return (
    <span
      style={{
        fontSize: 11.5,
        fontWeight: 700,
        padding: "2px 8px",
        borderRadius: 6,
        background: seen ? THEME.greenLight : THEME.slate50,
        color: seen ? THEME.green : THEME.slate500,
        whiteSpace: "nowrap",
      }}
    >
      {seen ? "Seen by patient" : "Not seen yet"}
    </span>
  );
}

// Patients who were warned and are no longer on the At Risk list: waiting for their next session. Nothing
// else shows them, so a warned patient who does not come back would otherwise be forgotten.
export default function WarnedPatients({ patients, receipts, onClear, isMobile }) {
  if (patients.length === 0) return null;
  const sorted = [...patients].sort((a, b) => (a.warningSentAt?.getTime() ?? 0) - (b.warningSentAt?.getTime() ?? 0));
  return (
    <div style={{ marginTop: 28 }}>
      <div style={{ fontSize: 15, fontWeight: 700, color: THEME.slate800, marginBottom: 4 }}>
        Warned — waiting for their next session
      </div>
      <div style={{ fontSize: 12.5, color: THEME.slate500, marginBottom: 12 }}>
        The warning clears itself after their next session. If they have not exercised after {FOLLOW_UP_DAYS} days,
        it is worth getting in touch.
      </div>
      <div style={{ display: "grid", gap: 10 }}>
        {sorted.map((p) => {
          const days = daysSince(p.warningSentAt);
          const overdue = days !== null && days >= FOLLOW_UP_DAYS;
          return (
            <Card key={p.id} style={{ padding: isMobile ? "14px 16px" : "14px 20px" }}>
              <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "6px 12px" }}>
                <div style={{ flex: "1 1 180px", minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800, overflowWrap: "anywhere" }}>
                    {p.name}
                  </div>
                  <div style={{ fontSize: 12.5, color: THEME.slate600, marginTop: 2, overflowWrap: "anywhere" }}>
                    “{p.warning}”
                  </div>
                </div>
                <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 8 }}>
                  {days !== null && (
                    <span style={{ fontSize: 12, color: overdue ? THEME.red : THEME.slate500, fontWeight: overdue ? 700 : 500 }}>
                      Sent {ageLabel(days)}
                      {overdue ? " — no session since" : ""}
                    </span>
                  )}
                  <SeenBadge readAt={receipts.get(p.id)} />
                  <button
                    onClick={() => onClear(p.id)}
                    style={{
                      fontSize: 12,
                      color: THEME.amberDim,
                      background: "none",
                      border: "none",
                      cursor: "pointer",
                      fontWeight: 600,
                    }}
                  >
                    Clear
                  </button>
                </div>
              </div>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
