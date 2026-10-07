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
import { SectionHead, Card, WarnedPatients, SeenBadge } from "../components";
import useToast from "../../useToast";
import PatientUseCases from "../../../domain/physio/usecases/PatientUseCases";
import SessionUseCases from "../../../domain/physio/usecases/SessionUseCases";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { tooltipProps, axisTick, pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";

// One tap to fill the warning box. The physio can still edit the text before sending.
const WARNING_TEMPLATES = [
  "Please reduce the intensity and move more slowly.",
  "Please rest today and stop if you feel pain.",
  "Please keep your movements within a comfortable range.",
  "Please contact me before your next session.",
];

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
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: 8 }}>
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
  // Worst first: unsafe movement and high pain before a falling ROM or a quiet patient, then lowest ROM.
  const atRisk = patients
    .filter((p) => p.status === "at-risk")
    .sort((a, b) => b.riskSeverity - a.riskSeverity || a.rom - b.rom);
  // Warned and no longer on the list: waiting for their next session.
  const warned = patients.filter((p) => p.approved && p.warning && p.status !== "at-risk");
  // Whether each warned patient has tapped "Got it" in their app. Reloaded when the set of open warnings changes.
  const [receipts, setReceipts] = useState(() => new Map());
  const openWarningsKey = patients
    .filter((p) => p.warning)
    .map((p) => `${p.id}:${p.warning}`)
    .join("|");
  useEffect(() => {
    let cancelled = false;
    PatientUseCases.getOpenWarningReceipts()
      .then((map) => {
        if (!cancelled) setReceipts(map);
      })
      .catch(() => {
        if (!cancelled) setReceipts(new Map());
      });
    return () => {
      cancelled = true;
    };
  }, [openWarningsKey]);
  const isMobile = useIsMobile();
  const { toastNode, showToast } = useToast();


  const saveWarning = async (id, message) => {
    await PatientUseCases.setWarning(id, message);
    // Sending a warning takes the patient off this list (they come back only if sessions done after it
    // show a new problem); the portal's next refresh works the same out from patients.risk_reviewed_at.
    setPatients((prev) =>
      prev.map((x) =>
        x.id !== id
          ? x
          : x.with(message ? { warning: message, status: x.status === "at-risk" ? "active" : x.status, riskReasons: [] } : { warning: message })
      )
    );
  };

  const sendWarning = async (id) => {
    const msg = warnInputs[id]?.trim();
    if (!msg) return;
    const p = patients.find((x) => x.id === id);
    try {
      await saveWarning(id, msg);
      setWarnInputs((prev) => ({ ...prev, [id]: "" }));
      showToast(`Warning sent to ${p.name}. They're off the At Risk list; the warning is on their patient page.`);
    } catch (err) {
      showToast(err.message || "Couldn't send the warning. Try again.", { error: true });
    }
  };

  const clearWarning = async (id) => {
    try {
      await saveWarning(id, null);
    } catch (err) {
      showToast(err.message || "Couldn't clear the warning. Try again.", { error: true });
    }
  };

  return (
    <div style={{ padding: pagePadding(isMobile), position: "relative" }}>
      {toastNode}

      <SectionHead
        title="At-risk patients"
        sub={`${atRisk.length} ${atRisk.length === 1 ? "patient needs" : "patients need"} attention`}
      />

      {atRisk.length === 0 ? (
        <Card style={{ padding: isMobile ? "36px 20px" : "48px", textAlign: "center" }}>
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
                  padding: isMobile ? "14px 16px" : "16px 24px",
                  display: "flex",
                  flexWrap: "wrap",
                  alignItems: "center",
                  gap: isMobile ? 10 : 14,
                  borderBottom: `1px solid ${THEME.slate200}`,
                }}
              >
                <div
                  style={{
                    width: 44,
                    height: 44,
                    borderRadius: "50%",
                    background: THEME.red,
                    color: THEME.onFill,
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
                <div style={{ flex: "1 1 140px", minWidth: 0 }}>
                  <div style={{ fontSize: 16, fontWeight: 700, color: THEME.slate800, overflowWrap: "anywhere" }}>
                    {p.name}
                  </div>
                  <div style={{ fontSize: 13, color: THEME.slate500 }}>
                    {[p.injury, p.regId].filter(Boolean).join(" · ")}
                  </div>
                  {p.riskReasons.length > 0 && (
                    <div style={{ fontSize: 12.5, color: THEME.red, fontWeight: 600, marginTop: 4 }}>
                      {p.riskReasons.join(" · ")}
                    </div>
                  )}
                </div>
                <div style={{ fontSize: isMobile ? 18 : 22, fontWeight: 800, color: THEME.red, whiteSpace: "nowrap" }}>
                  {p.rom}% ROM
                </div>
              </div>

              {/* Body content */}
              <div style={{ padding: isMobile ? "16px" : "20px 24px" }}>
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
                        <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate200} />
                        <XAxis dataKey="w" tick={{ ...axisTick(), fontSize: 10 }} axisLine={false} tickLine={false} />
                        <YAxis
                          tick={{ ...axisTick(), fontSize: 10 }}
                          axisLine={false}
                          tickLine={false}
                          domain={[0, "auto"]}
                        />
                        <Tooltip {...tooltipProps()} formatter={(v) => [`${v}%`, "ROM"]} />
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
                      gap: 10,
                    }}
                  >
                    <span style={{ fontSize: 13, color: THEME.amberDim, fontWeight: 600 }}>
                      Active warning: {p.warning}
                      <span style={{ fontWeight: 400 }}> (clears after the patient's next session)</span>{" "}
                      <SeenBadge readAt={receipts.get(p.id)} />
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
                <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 10 }}>
                  {WARNING_TEMPLATES.map((t) => (
                    <button
                      key={t}
                      type="button"
                      onClick={() => setWarnInputs((prev) => ({ ...prev, [p.id]: t }))}
                      style={{
                        fontSize: 12,
                        padding: "5px 10px",
                        borderRadius: 999,
                        border: `1px solid ${THEME.slate200}`,
                        background: THEME.slate50,
                        color: THEME.slate600,
                        cursor: "pointer",
                      }}
                    >
                      {t}
                    </button>
                  ))}
                </div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
                  <input
                    placeholder="Send a warning to patient (e.g. 'Please reduce intensity…')"
                    value={warnInputs[p.id] || ""}
                    onChange={(e) =>
                      setWarnInputs((prev) => ({ ...prev, [p.id]: e.target.value }))
                    }
                    onKeyDown={(e) => e.key === "Enter" && sendWarning(p.id)}
                    style={{
                      flex: "1 1 220px",
                      minWidth: 0,
                      padding: "10px 14px",
                      border: `1.5px solid ${THEME.slate200}`,
                      borderRadius: 10,
                      fontSize: 13,
                      color: THEME.slate800,
                      // Inputs stay white in dark mode unless told otherwise.
                      background: THEME.slate50,
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
                      color: THEME.onFill,
                      flex: isMobile ? "1 1 100%" : "0 0 auto",
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

      <WarnedPatients patients={warned} receipts={receipts} onClear={clearWarning} isMobile={isMobile} />
    </div>
  );
}

export default AtRiskPage;
