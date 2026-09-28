import { useState } from "react";
import { THEME } from "../../../infrastructure/physio/constants";
import { SectionHead, Card } from "../components";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";

function ApprovalsPage({ patients, setPatients }) {
  const [toast, setToast] = useState(null);
  const pending = patients.filter((p) => !p.approved);
  const isMobile = useIsMobile();

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  };

  const approve = (id) => {
    const p = patients.find((x) => x.id === id);
    setPatients((prev) => prev.map((x) => (x.id === id ? { ...x, approved: true } : x)));
    showToast(`${p.name} approved and activated.`);
  };

  const reject = (id) => {
    const p = patients.find((x) => x.id === id);
    setPatients((prev) => prev.filter((x) => x.id !== id));
    showToast(`${p.name} removed.`);
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
            background: THEME.navy,
            color: THEME.white,
            borderRadius: 10,
            padding: "12px 20px",
            zIndex: 200,
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          ✓ {toast}
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
                    {[p.regId, p.injury].filter(Boolean).join(" · ") || "No injury on file"}
                  </div>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "repeat(3, minmax(0, max-content))",
                      gap: isMobile ? 8 : 16,
                      marginTop: 10,
                    }}
                  >
                    {[
                      ["Current ROM", `${p.rom}%`],
                      ["Wearable", p.wearable ? "Yes" : "No"],
                      ["Trend", p.trend > 0 ? `+${p.trend}°` : `${p.trend}°`],
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
                    style={{
                      flex: 1,
                      padding: "10px 20px",
                      border: `1px solid ${THEME.slate200}`,
                      borderRadius: 10,
                      background: THEME.surface,
                      color: THEME.slate600,
                      fontWeight: 600,
                      cursor: "pointer",
                    }}
                  >
                    Decline
                  </button>
                  <button
                    onClick={() => approve(p.id)}
                    style={{
                      flex: 1,
                      padding: "10px 20px",
                      background: THEME.teal,
                      border: "none",
                      borderRadius: 10,
                      color: THEME.onFill,
                      fontWeight: 700,
                      cursor: "pointer",
                    }}
                  >
                    Approve
                  </button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

export default ApprovalsPage;
