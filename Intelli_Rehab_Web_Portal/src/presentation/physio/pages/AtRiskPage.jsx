import { useState, useEffect } from "react";
import {
  ResponsiveContainer,
  LineChart,
  Line,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
} from "recharts";
import { THEME } from "../../../infrastructure/physio/constants";
import { SectionHead, Card } from "../components";
import SessionUseCases from "../../../domain/physio/usecases/SessionUseCases";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";

// Each at-risk card fetches its own patient's EMG independently — there's
// no bulk "EMG for every at-risk patient" query, and most clinics won't
// have many at-risk patients open on screen at once.
function EmgIndicators({ patientId }) {
  const [emg, setEmg] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    SessionUseCases.getLatestEmgForPatient(patientId)
      .then((data) => {
        if (!cancelled) setEmg(data);
      })
      .catch(() => {
        if (!cancelled) setEmg([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [patientId]);

  if (loading) {
    return <div style={{ fontSize: 12, color: THEME.slate400 }}>Loading…</div>;
  }
  if (emg.length === 0) {
    return <div style={{ fontSize: 12, color: THEME.slate400 }}>No session data yet.</div>;
  }

  return (
    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
      {emg.map((m) => (
        <div key={m.muscle} style={{ background: THEME.slate50, padding: "10px 12px", borderRadius: 9 }}>
          <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
            <span style={{ fontSize: 12, color: THEME.slate600 }}>{m.muscle}</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: THEME.slate600 }}>{m.val}%</span>
          </div>
          <div style={{ height: 5, background: THEME.slate200, borderRadius: 99 }}>
            <div
              style={{
                width: `${m.val}%`,
                height: "100%",
                background: m.val < 30 ? THEME.red : THEME.amber,
                borderRadius: 99,
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

function AtRiskPage({ patients, setPatients }) {
  const [warnInputs, setWarnInputs] = useState({});
  const [toast, setToast] = useState(null);
  const atRisk = patients.filter((p) => p.status === "at-risk");

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  };

  const sendWarning = (id) => {
    const msg = warnInputs[id]?.trim();
    if (!msg) return;
    const p = patients.find((x) => x.id === id);
    setPatients((prev) => prev.map((x) => (x.id === id ? { ...x, warning: msg } : x)));
    setWarnInputs((prev) => ({ ...prev, [id]: "" }));
    showToast(`Warning sent to ${p.name}`);
  };

  const clearWarning = (id) => {
    setPatients((prev) => prev.map((x) => (x.id === id ? { ...x, warning: null } : x)));
  };

  return (
    <div style={{ padding: "28px 32px", position: "relative" }}>
      {toast && (
        <div
          style={{
            position: "fixed",
            top: 24,
            right: 32,
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

      <SectionHead title="At-risk patients" sub={`${atRisk.length} patients need attention`} />

      {atRisk.length === 0 ? (
        <Card style={{ padding: "48px", textAlign: "center" }}>
          <div style={{ fontSize: 14, color: THEME.slate400 }}>
            No at-risk patients right now.
          </div>
        </Card>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          {atRisk.map((p) => (
            <Card key={p.id} style={{ overflow: "hidden" }}>
              {/* Header with ROM indicator */}
              <div
                style={{
                  background: THEME.redLight,
                  padding: "16px 24px",
                  display: "flex",
                  alignItems: "center",
                  gap: 14,
                  borderBottom: `1px solid ${THEME.slate200}`,
                }}
              >
                <div
                  style={{
                    width: 44,
                    height: 44,
                    borderRadius: "50%",
                    background: THEME.red,
                    color: THEME.white,
                    fontSize: 15,
                    fontWeight: 700,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    flexShrink: 0,
                  }}
                >
                  {VisualizationService.getInitials(p.name)}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 16, fontWeight: 700, color: THEME.slate800 }}>
                    {p.name}
                  </div>
                  <div style={{ fontSize: 13, color: THEME.slate500 }}>
                    {p.injury} · {p.regId}
                  </div>
                </div>
                <div style={{ fontSize: 22, fontWeight: 800, color: THEME.red }}>{p.rom}% ROM</div>
              </div>

              {/* Body content */}
              <div style={{ padding: "20px 24px" }}>
                {/* ROM trend chart */}
                <div style={{ marginBottom: 18 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: THEME.slate600, marginBottom: 10 }}>
                    ROM trend (last 6 weeks)
                  </div>
                  {p.romWeekly.length === 0 ? (
                    <div
                      style={{
                        height: 100,
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        fontSize: 12,
                        color: THEME.slate400,
                      }}
                    >
                      No session data yet.
                    </div>
                  ) : (
                    <ResponsiveContainer width="100%" height={100}>
                      <LineChart data={p.romWeekly} margin={{ top: 5, right: 10, bottom: 0, left: -28 }}>
                        <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate100} />
                        <XAxis
                          dataKey="w"
                          tick={{ fontSize: 10, fill: THEME.slate400 }}
                          axisLine={false}
                          tickLine={false}
                        />
                        <YAxis
                          tick={{ fontSize: 10, fill: THEME.slate400 }}
                          axisLine={false}
                          tickLine={false}
                          domain={[0, 100]}
                        />
                        <Tooltip
                          contentStyle={{ borderRadius: 8, fontSize: 11 }}
                          formatter={(v) => [`${v}%`, "ROM"]}
                        />
                        <Line
                          type="monotone"
                          dataKey="v"
                          stroke={THEME.red}
                          strokeWidth={2.5}
                          dot={{ fill: THEME.red, r: 3 }}
                        />
                      </LineChart>
                    </ResponsiveContainer>
                  )}
                </div>

                {/* EMG indicators */}
                <div style={{ marginBottom: 18 }}>
                  <EmgIndicators patientId={p.id} />
                </div>

                {/* Active warning display */}
                {p.warning && (
                  <div
                    style={{
                      background: THEME.amberLight,
                      border: `1px solid ${THEME.amber}`,
                      borderRadius: 10,
                      padding: "12px 14px",
                      marginBottom: 14,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                    }}
                  >
                    <span style={{ fontSize: 13, color: THEME.amberDim, fontWeight: 600 }}>
                      Active warning: {p.warning}
                    </span>
                    <button
                      onClick={() => clearWarning(p.id)}
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
                )}

                {/* Warning input */}
                <div style={{ display: "flex", gap: 10 }}>
                  <input
                    placeholder="Send a warning to patient (e.g. 'Please reduce intensity…')"
                    value={warnInputs[p.id] || ""}
                    onChange={(e) =>
                      setWarnInputs((prev) => ({ ...prev, [p.id]: e.target.value }))
                    }
                    onKeyDown={(e) => e.key === "Enter" && sendWarning(p.id)}
                    style={{
                      flex: 1,
                      padding: "10px 14px",
                      border: `1.5px solid ${THEME.slate200}`,
                      borderRadius: 10,
                      fontSize: 13,
                      color: THEME.slate800,
                      outline: "none",
                    }}
                  />
                  <button
                    onClick={() => sendWarning(p.id)}
                    style={{
                      padding: "10px 18px",
                      background: THEME.amber,
                      border: "none",
                      borderRadius: 10,
                      color: THEME.white,
                      fontWeight: 700,
                      fontSize: 13,
                      cursor: "pointer",
                    }}
                  >
                    Send warning
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

export default AtRiskPage;
