import { useState } from "react";
import { THEME } from "../../../infrastructure/physio/constants";
import { SectionHead, Card, PatientDetails, chosenPhysioLabel } from "../components";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";
import PatientUseCases from "../../../domain/physio/usecases/PatientUseCases";
import { armLabel, jointLabel, injuryTypeLabel, painLabel, ageFrom } from "../../../domain/physio/utils/patientLabels";

// "Right arm · Elbow · Fracture" from the patient's self-reported injury,
// falling back to the denormalised patients.injury text.
const injurySummary = (p) => {
  const i = p.injuryDetails;
  if (!i) return p.injury;
  return [i.side && `${armLabel(i.side)} arm`, jointLabel(i.joint), injuryTypeLabel(i.type)].filter(Boolean).join(" · ");
};

function ApprovalsPage({ patients, setPatients, currentPhysioId }) {
  const [toast, setToast] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [expandedId, setExpandedId] = useState(null);
  // Patients who picked this physio first; the rest chose a colleague at
  // the same clinic but are still visible (and approvable) under RLS.
  const pending = patients
    .filter((p) => !p.approved)
    .sort((a, b) => (b.profile.physioId === currentPhysioId) - (a.profile.physioId === currentPhysioId));
  const isMobile = useIsMobile();

  const showToast = (msg, isError = false) => {
    setToast({ msg, isError });
    setTimeout(() => setToast(null), 3000);
  };

  const approve = async (id) => {
    const p = patients.find((x) => x.id === id);
    setBusyId(id);
    try {
      await PatientUseCases.approvePatient(id);
      setPatients((prev) => prev.map((x) => (x.id === id ? { ...x, approved: true } : x)));
      showToast(`${p.name} approved and activated.`);
    } catch (e) {
      showToast(e.message, true);
    } finally {
      setBusyId(null);
    }
  };

  const reject = async (id) => {
    const p = patients.find((x) => x.id === id);
    setBusyId(id);
    try {
      await PatientUseCases.removePatient(id);
      setPatients((prev) => prev.filter((x) => x.id !== id));
      showToast(`${p.name} removed.`);
    } catch (e) {
      showToast(e.message, true);
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div style={{ padding: pagePadding(isMobile), position: "relative" }}>
      {toast && (
        <div
          style={{
            position: "fixed",
            top: isMobile ? 16 : 24,
            right: isMobile ? 16 : 32,
            left: isMobile ? 16 : "auto",
            background: toast.isError ? THEME.red : THEME.navy,
            color: THEME.white,
            borderRadius: 10,
            padding: "12px 20px",
            zIndex: 200,
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          {toast.isError ? "!" : "✓"} {toast.msg}
        </div>
      )}

      <SectionHead
        title="New patient approvals"
        sub={`${pending.length} ${pending.length === 1 ? "patient" : "patients"} awaiting your review`}
      />

      {pending.length === 0 ? (
        <Card style={{ padding: isMobile ? "36px 20px" : "48px", textAlign: "center" }}>
          <div style={{ fontSize: 32, marginBottom: 12, color: THEME.green }}>✓</div>
          <div style={{ fontSize: 15, fontWeight: 600, color: THEME.slate800, marginBottom: 6 }}>
            All caught up
          </div>
          <div style={{ fontSize: 13, color: THEME.slate400 }}>
            No pending approvals right now.
          </div>
        </Card>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          {pending.map((p) => (
            <Card key={p.id} style={{ padding: isMobile ? "18px 16px" : "22px 26px" }}>
              <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 14 }}>
                <div
                  style={{
                    width: 46,
                    height: 46,
                    borderRadius: "50%",
                    background: THEME.navy,
                    color: THEME.white,
                    fontSize: 16,
                    fontWeight: 700,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    flexShrink: 0,
                  }}
                >
                  {VisualizationService.getInitials(p.name)}
                </div>

                <div style={{ flex: "1 1 260px", minWidth: 0 }}>
                  <div style={{ fontSize: 16, fontWeight: 700, color: THEME.slate800, overflowWrap: "anywhere" }}>
                    {p.name}
                  </div>
                  <div style={{ fontSize: 13, color: THEME.slate500 }}>
                    {[
                      injurySummary(p),
                      ageFrom(p.profile.dateOfBirth) != null && `Age ${ageFrom(p.profile.dateOfBirth)}`,
                      p.injuryDetails?.painLevel != null && `Pain ${painLabel(p.injuryDetails.painLevel)}`,
                    ]
                      .filter(Boolean)
                      .join(" · ") || "No injury on file"}
                  </div>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: isMobile ? "minmax(0, 1fr)" : "repeat(3, minmax(0, max-content))",
                      gap: isMobile ? 8 : 16,
                      marginTop: 10,
                    }}
                  >
                    {[
                      ["Chose", chosenPhysioLabel(p, currentPhysioId)],
                      ["Wearable", p.device?.serial ?? (p.wearable ? "Paired" : "Not paired")],
                      ["Baseline", p.baseline ? `${Math.round(p.baseline.range)}° range` : "Not calibrated"],
                    ].map(([l, v]) => (
                      <div
                        key={l}
                        style={{
                          background: THEME.slate50,
                          padding: isMobile ? "8px 10px" : "8px 14px",
                          borderRadius: 9,
                          minWidth: 0,
                        }}
                      >
                        <div style={{ fontSize: 11, color: THEME.slate400, whiteSpace: "nowrap" }}>{l}</div>
                        <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800 }}>{v}</div>
                      </div>
                    ))}
                  </div>
                </div>

                <div style={{ display: "flex", gap: 10, flex: isMobile ? "1 1 100%" : "0 0 auto" }}>
                  <button
                    onClick={() => reject(p.id)}
                    disabled={busyId === p.id}
                    style={{
                      flex: 1,
                      padding: "10px 20px",
                      border: `1px solid ${THEME.slate200}`,
                      borderRadius: 10,
                      background: THEME.surface,
                      color: THEME.slate600,
                      fontWeight: 600,
                      cursor: busyId === p.id ? "wait" : "pointer",
                    }}
                  >
                    Decline
                  </button>
                  <button
                    onClick={() => approve(p.id)}
                    disabled={busyId === p.id}
                    style={{
                      flex: 1,
                      padding: "10px 20px",
                      background: THEME.teal,
                      border: "none",
                      borderRadius: 10,
                      color: THEME.onFill,
                      fontWeight: 700,
                      cursor: busyId === p.id ? "wait" : "pointer",
                    }}
                  >
                    Approve
                  </button>
                </div>
              </div>

              <button
                onClick={() => setExpandedId(expandedId === p.id ? null : p.id)}
                style={{
                  marginTop: 12,
                  padding: 0,
                  background: "none",
                  border: "none",
                  color: THEME.teal,
                  fontSize: 13,
                  fontWeight: 600,
                  cursor: "pointer",
                }}
              >
                {expandedId === p.id ? "Hide details ▲" : "Show all details ▼"}
              </button>
              {expandedId === p.id && (
                <div style={{ marginTop: 14, paddingTop: 14, borderTop: `1px solid ${THEME.slate200}` }}>
                  <PatientDetails patient={p} currentPhysioId={currentPhysioId} />
                </div>
              )}
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

export default ApprovalsPage;
