import { useState, useEffect } from "react";
import {
  ResponsiveContainer,
  AreaChart,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  Area,
} from "recharts";
import { THEME, EXERCISES } from "../../../infrastructure/physio/constants";
import { Card, SectionHead, RomBar, Badge } from "../components";
import SessionUseCases from "../../../domain/physio/usecases/SessionUseCases";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { tooltipProps, axisTick, pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";

function AssignExerciseModal({ patient, onClose, onAssign }) {
  const [exId, setExId] = useState(patient.currentExercise?.id || 1);
  const [sets, setSets] = useState(patient.currentExercise?.sets || 3);
  const [reps, setReps] = useState(patient.currentExercise?.reps || 10);
  const [romTarget, setRomTarget] = useState(patient.currentExercise?.romTarget || 70);
  const surface = THEME.surface;
  const [freq, setFreq] = useState(patient.currentExercise?.freq || "Daily");
  const isMobile = useIsMobile();

  const ex = EXERCISES.find((e) => e.id === exId);
  const inp = {
    width: "100%",
    padding: "10px 12px",
    border: `1.5px solid ${THEME.slate200}`,
    borderRadius: 9,
    fontSize: 14,
    color: THEME.slate800,
    // Without an explicit background, <select>/<input> stay white in dark
    // mode while their text turns near-white.
    background: THEME.slate50,
    outline: "none",
    boxSizing: "border-box",
  };

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0,0,0,0.45)",
        zIndex: 100,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 16,
      }}
    >
      <div
        style={{
          background: surface,
          borderRadius: 18,
          padding: isMobile ? 20 : 32,
          width: 520,
          maxWidth: "100%",
          maxHeight: "90dvh",
          overflowY: "auto",
          boxShadow: "0 20px 60px rgba(0,0,0,0.25)",
        }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-start",
            marginBottom: 24,
          }}
        >
          <div>
            <div style={{ fontSize: 18, fontWeight: 700, color: THEME.slate800 }}>
              Assign exercise session
            </div>
            <div style={{ fontSize: 13, color: THEME.slate400, marginTop: 2 }}>
              For {patient.name} · {patient.injury}
            </div>
          </div>
          <button
            onClick={onClose}
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              border: `1px solid ${THEME.slate200}`,
              background: surface,
              cursor: "pointer",
              fontSize: 18,
              color: THEME.slate500,
            }}
          >
            ×
          </button>
        </div>

        <div style={{ marginBottom: 16 }}>
          <label
            style={{
              fontSize: 12,
              fontWeight: 600,
              color: THEME.slate600,
              display: "block",
              marginBottom: 6,
            }}
          >
            EXERCISE
          </label>
          <select
            value={exId}
            onChange={(e) => setExId(Number(e.target.value))}
            style={inp}
          >
            {EXERCISES.map((e) => (
              <option key={e.id} value={e.id}>
                {e.name}
              </option>
            ))}
          </select>
        </div>

        {ex && (
          <div
            style={{
              background: THEME.tealLight,
              borderRadius: 10,
              padding: "12px 14px",
              marginBottom: 18,
            }}
          >
            <div style={{ fontSize: 12, fontWeight: 600, color: THEME.tealDim }}>
              Target: {ex.target} · {ex.difficulty}
            </div>
            <div style={{ fontSize: 12, color: THEME.slate600, marginTop: 4 }}>
              {ex.desc}
            </div>
          </div>
        )}

        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, minmax(0, 1fr))", gap: 12, marginBottom: 16 }}>
          {[
            ["SETS", sets, setSets, 1, 6],
            ["REPS", reps, setReps, 3, 20],
            ["ROM TARGET (%)", romTarget, setRomTarget, 20, 100],
          ].map(([l, v, fn, min, max]) => (
            <div key={l}>
              <label
                style={{
                  fontSize: 12,
                  fontWeight: 600,
                  color: THEME.slate600,
                  display: "block",
                  marginBottom: 6,
                }}
              >
                {l}
              </label>
              <input
                type="number"
                min={min}
                max={max}
                value={v}
                onChange={(e) => fn(Number(e.target.value))}
                style={inp}
              />
            </div>
          ))}
        </div>

        <div style={{ marginBottom: 24 }}>
          <label
            style={{
              fontSize: 12,
              fontWeight: 600,
              color: THEME.slate600,
              display: "block",
              marginBottom: 6,
            }}
          >
            FREQUENCY
          </label>
          <select value={freq} onChange={(e) => setFreq(e.target.value)} style={inp}>
            {["Daily", "Every other day", "3× per week", "Weekly"].map((f) => (
              <option key={f}>{f}</option>
            ))}
          </select>
        </div>

        <div style={{ display: "flex", gap: 10 }}>
          <button
            onClick={onClose}
            style={{
              flex: 1,
              padding: "12px",
              border: `1px solid ${THEME.slate200}`,
              borderRadius: 10,
              background: surface,
              color: THEME.slate600,
              fontWeight: 600,
              cursor: "pointer",
            }}
          >
            Cancel
          </button>
          <button
            onClick={() => onAssign({ exId, sets, reps, romTarget, freq })}
            style={{
              flex: 2,
              padding: "12px",
              background: THEME.teal,
              border: "none",
              borderRadius: 10,
              color: THEME.onFill,
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            Assign session
          </button>
        </div>
      </div>
    </div>
  );
}

function PatientsPage({ patients, setPatients, selectedId, setSelectedId }) {
  const [showAssign, setShowAssign] = useState(false);
  const [toast, setToast] = useState(null);
  const [emg, setEmg] = useState([]);
  const [emgLoading, setEmgLoading] = useState(false);
  const selected = patients.find((p) => p.id === selectedId);

  // EMG is per-muscle readings from the patient's most recent session —
  // only needed for whichever one patient is currently open, so it's
  // fetched on demand instead of bulk-loaded with the patient list.
  useEffect(() => {
    if (!selectedId) {
      setEmg([]);
      return;
    }
    let cancelled = false;
    setEmgLoading(true);
    SessionUseCases.getLatestEmgForPatient(selectedId)
      .then((data) => {
        if (!cancelled) setEmg(data);
      })
      .catch(() => {
        if (!cancelled) setEmg([]);
      })
      .finally(() => {
        if (!cancelled) setEmgLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [selectedId]);

  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  };

  const handleAssign = ({ exId, sets, reps, romTarget, freq }) => {
    setPatients((prev) =>
      prev.map((p) =>
        p.id === selectedId
          ? { ...p, currentExercise: { id: exId, sets, reps, romTarget, freq } }
          : p
      )
    );
    setShowAssign(false);
    showToast(`Exercise assigned to ${selected.name}`);
  };

  const approvedPatients = patients.filter((p) => p.approved);
  const isMobile = useIsMobile();
  // Phones get master → detail: the list, or one patient with a back link.
  const showList = !isMobile || !selected;
  const showDetail = !isMobile || selected;

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
            boxShadow: "0 8px 24px rgba(0,0,0,0.2)",
          }}
        >
          ✓ {toast}
        </div>
      )}
      {showAssign && selected && (
        <AssignExerciseModal
          patient={selected}
          onClose={() => setShowAssign(false)}
          onAssign={handleAssign}
        />
      )}

      {isMobile && selected ? (
        <button
          onClick={() => setSelectedId(null)}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 6,
            background: "none",
            border: "none",
            padding: "4px 0",
            marginBottom: 14,
            color: THEME.teal,
            fontWeight: 700,
            fontSize: 14,
            cursor: "pointer",
          }}
        >
          ← All patients
        </button>
      ) : (
        <SectionHead title="Patients" sub={`${approvedPatients.length} active patients`} />
      )}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: isMobile ? "minmax(0, 1fr)" : "300px minmax(0, 1fr)",
          gap: 20,
          alignItems: "start",
        }}
      >
        {/* Patient list */}
        {showList && (
        <Card style={{ overflow: "hidden" }}>
          {approvedPatients.length === 0 ? (
            <div style={{ padding: "48px 20px", textAlign: "center", color: THEME.slate400, fontSize: 13 }}>
              No approved patients yet.
            </div>
          ) : (
            approvedPatients.map((p, i) => (
            <div
              key={p.id}
              onClick={() => setSelectedId(p.id)}
              style={{
                padding: "14px 16px",
                borderBottom: i < approvedPatients.length - 1 ? `1px solid ${THEME.slate200}` : "none",
                cursor: "pointer",
                background: selectedId === p.id ? THEME.tealLight : "transparent",
                borderLeft: selectedId === p.id ? `3px solid ${THEME.teal}` : "3px solid transparent",
                transition: "all 0.15s",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                <div
                  style={{
                    width: 36,
                    height: 36,
                    borderRadius: "50%",
                    background: selectedId === p.id ? THEME.teal : THEME.navy,
                    color: selectedId === p.id ? THEME.onFill : THEME.white,
                    fontSize: 13,
                    fontWeight: 700,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    flexShrink: 0,
                  }}
                >
                  {VisualizationService.getInitials(p.name)}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      fontSize: 13,
                      fontWeight: 600,
                      color: THEME.slate800,
                      display: "flex",
                      alignItems: "center",
                      gap: 6,
                      minWidth: 0,
                    }}
                  >
                    <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {p.name}
                    </span>
                    {p.warning && (
                      <span
                        style={{
                          width: 7,
                          height: 7,
                          borderRadius: "50%",
                          background: THEME.amber,
                          display: "inline-block",
                        }}
                      />
                    )}
                    {p.status === "at-risk" && (
                      <span
                        style={{
                          width: 7,
                          height: 7,
                          borderRadius: "50%",
                          background: THEME.red,
                          display: "inline-block",
                        }}
                      />
                    )}
                  </div>
                  <div
                    style={{
                      fontSize: 11,
                      color: THEME.slate400,
                      marginTop: 1,
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {p.injury}
                  </div>
                </div>
                <Badge status={p.status} />
              </div>
              <div style={{ marginTop: 8 }}>
                <RomBar value={p.rom} height={4} />
              </div>
            </div>
            ))
          )}
        </Card>
        )}

        {/* Patient detail - using the remaining space */}
        {!showDetail ? null : selected ? (
          <div style={{ display: "flex", flexDirection: "column", gap: isMobile ? 14 : 18, minWidth: 0 }}>
            <Card style={{ padding: isMobile ? "18px 16px" : "22px 26px" }}>
              <div
                style={{
                  display: "flex",
                  flexWrap: "wrap",
                  gap: 14,
                  alignItems: "flex-start",
                  justifyContent: "space-between",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 14, minWidth: 0, flex: "1 1 240px" }}>
                  <div
                    style={{
                      width: 52,
                      height: 52,
                      borderRadius: "50%",
                      background: THEME.navy,
                      color: THEME.white,
                      fontSize: 18,
                      fontWeight: 700,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      flexShrink: 0,
                    }}
                  >
                    {VisualizationService.getInitials(selected.name)}
                  </div>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: isMobile ? 18 : 20, fontWeight: 800, color: THEME.slate800, overflowWrap: "anywhere" }}>
                      {selected.name}
                    </div>
                    <div style={{ fontSize: 13, color: THEME.slate500 }}>
                      {[selected.regId, selected.injury].filter(Boolean).join(" · ")}
                    </div>
                    <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 8, marginTop: 6 }}>
                      <Badge status={selected.status} />
                      <span
                        style={{
                          fontSize: 12,
                          color: selected.wearable ? THEME.green : THEME.slate400,
                        }}
                      >
                        {selected.wearable ? "● Wearable connected" : "○ No wearable"}
                      </span>
                      <span style={{ fontSize: 12, color: THEME.slate400 }}>
                        🔥 {selected.streak} day streak
                      </span>
                    </div>
                  </div>
                </div>
                <button
                  onClick={() => setShowAssign(true)}
                  style={{
                    padding: "10px 20px",
                    background: THEME.teal,
                    border: "none",
                    borderRadius: 10,
                    color: THEME.onFill,
                    flex: isMobile ? "1 1 100%" : "0 0 auto",
                    fontWeight: 700,
                    fontSize: 13,
                    cursor: "pointer",
                  }}
                >
                  Assign exercise
                </button>
              </div>
              {selected.warning && (
                <div
                  style={{
                    marginTop: 14,
                    background: THEME.amberLight,
                    border: `1px solid ${THEME.amber}`,
                    borderRadius: 10,
                    padding: "10px 14px",
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  <span style={{ fontSize: 18 }}>⚠️</span>
                  <span style={{ fontSize: 13, color: THEME.amberDim, fontWeight: 600 }}>
                    {selected.warning}
                  </span>
                </div>
              )}
            </Card>

            {/* ROM + EMG charts */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: isMobile ? "minmax(0, 1fr)" : "repeat(2, minmax(0, 1fr))",
                gap: isMobile ? 14 : 18,
              }}
            >
              <Card style={{ padding: isMobile ? "18px 16px" : "20px 22px", minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800, marginBottom: 14 }}>
                  ROM progress
                </div>
                {selected.romWeekly.length === 0 ? (
                  <div
                    style={{
                      height: 150,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      fontSize: 13,
                      color: THEME.slate400,
                    }}
                  >
                    No session data yet.
                  </div>
                ) : (
                  <ResponsiveContainer width="100%" height={150}>
                    <AreaChart data={selected.romWeekly} margin={{ top: 5, right: 5, bottom: 0, left: -28 }}>
                      <defs>
                        <linearGradient id="rg2" x1="0" y1="0" x2="0" y2="1">
                          <stop
                            offset="5%"
                            stopColor={VisualizationService.getRomColor(selected.rom)}
                            stopOpacity={0.2}
                          />
                          <stop
                            offset="95%"
                            stopColor={VisualizationService.getRomColor(selected.rom)}
                            stopOpacity={0}
                          />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate200} />
                      <XAxis dataKey="w" tick={axisTick()} axisLine={false} tickLine={false} />
                      <YAxis tick={axisTick()} axisLine={false} tickLine={false} domain={[0, "auto"]} />
                      <Tooltip {...tooltipProps()} formatter={(v) => [`${v}%`, "ROM"]} />
                      <Area
                        type="monotone"
                        dataKey="v"
                        stroke={VisualizationService.getRomColor(selected.rom)}
                        strokeWidth={2.5}
                        fill="url(#rg2)"
                        dot={{ fill: VisualizationService.getRomColor(selected.rom), r: 3 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                )}
              </Card>

              <Card style={{ padding: isMobile ? "18px 16px" : "20px 22px", minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800, marginBottom: 14 }}>
                  Muscle activation (EMG)
                </div>
                {emgLoading ? (
                  <div style={{ fontSize: 13, color: THEME.slate400, textAlign: "center", padding: "24px 0" }}>
                    Loading…
                  </div>
                ) : emg.length === 0 ? (
                  <div style={{ fontSize: 13, color: THEME.slate400, textAlign: "center", padding: "24px 0" }}>
                    No session data yet.
                  </div>
                ) : (
                  emg.map((m) => (
                    <div key={m.muscle} style={{ marginBottom: 12 }}>
                      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                        <span style={{ fontSize: 12, color: THEME.slate600 }}>{m.muscle}</span>
                        <span style={{ fontSize: 12, fontWeight: 600, color: THEME.slate600 }}>
                          {m.val}%
                        </span>
                      </div>
                      <div style={{ height: 6, background: THEME.slate200, borderRadius: 99, overflow: "hidden" }}>
                        <div
                          style={{
                            width: `${m.val}%`,
                            height: "100%",
                            background: m.val > 70 ? THEME.red : m.val > 50 ? THEME.amber : THEME.teal,
                            borderRadius: 99,
                          }}
                        />
                      </div>
                    </div>
                  ))
                )}
              </Card>
            </div>

            {/* Current exercise */}
            {selected.currentExercise &&
              (() => {
                const ex = EXERCISES.find((e) => e.id === selected.currentExercise.id);
                return (
                  <Card style={{ padding: isMobile ? "18px 16px" : "20px 24px" }}>
                    <div
                      style={{
                        display: "flex",
                        flexWrap: "wrap",
                        gap: 16,
                        justifyContent: "space-between",
                        alignItems: "flex-start",
                      }}
                    >
                      <div>
                        <div
                          style={{
                            fontSize: 14,
                            fontWeight: 700,
                            color: THEME.slate800,
                            marginBottom: 4,
                          }}
                        >
                          Current exercise plan
                        </div>
                        <div style={{ fontSize: 18, fontWeight: 800, color: THEME.teal }}>
                          {ex?.name}
                        </div>
                        <div style={{ fontSize: 13, color: THEME.slate500, marginTop: 2 }}>
                          {ex?.target} · {ex?.difficulty}
                        </div>
                      </div>
                      <div
                        style={{
                          display: "grid",
                          gridTemplateColumns: isMobile ? "repeat(2, minmax(0, 1fr))" : "repeat(4, auto)",
                          gap: isMobile ? 10 : 16,
                          width: isMobile ? "100%" : "auto",
                        }}
                      >
                        {[
                          ["Sets", selected.currentExercise.sets],
                          ["Reps", selected.currentExercise.reps],
                          ["ROM target", `${selected.currentExercise.romTarget}%`],
                          ["Frequency", selected.currentExercise.freq],
                        ].map(([l, v]) => (
                          <div
                            key={l}
                            style={{
                              textAlign: "center",
                              background: THEME.slate50,
                              padding: "10px 14px",
                              borderRadius: 10,
                            }}
                          >
                            <div style={{ fontSize: 18, fontWeight: 800, color: THEME.slate800 }}>
                              {v}
                            </div>
                            <div style={{ fontSize: 11, color: THEME.slate400 }}>{l}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </Card>
                );
              })()}

            {/* Session history */}
            <Card style={{ overflow: "hidden" }}>
              <div style={{ padding: isMobile ? "14px 16px" : "16px 22px", borderBottom: `1px solid ${THEME.slate200}` }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800 }}>
                  Session history
                </div>
              </div>
              {selected.sessions.length === 0 ? (
                <div
                  style={{
                    padding: "24px",
                    textAlign: "center",
                    color: THEME.slate400,
                    fontSize: 13,
                  }}
                >
                  No sessions recorded yet.
                </div>
              ) : (
                <>
                  {!isMobile && (
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr 1fr 1fr 1.5fr",
                      padding: "10px 22px",
                      background: THEME.slate50,
                      borderBottom: `1px solid ${THEME.slate200}`,
                    }}
                  >
                    {["Date", "ROM", "Quality", "Fatigue", "Exercise"].map((h) => (
                      <div
                        key={h}
                        style={{
                          fontSize: 11,
                          fontWeight: 600,
                          color: THEME.slate400,
                          textTransform: "uppercase",
                          letterSpacing: 0.5,
                        }}
                      >
                        {h}
                      </div>
                    ))}
                  </div>
                  )}
                  {selected.sessions.map((s, i) => (
                    <div
                      key={i}
                      style={{
                        display: "grid",
                        // Phones: date + ROM on top, chips + exercise underneath.
                        gridTemplateColumns: isMobile ? "auto auto auto 1fr" : "1fr 1fr 1fr 1fr 1.5fr",
                        gap: isMobile ? "6px 10px" : 0,
                        padding: isMobile ? "12px 16px" : "12px 22px",
                        borderBottom:
                          i < selected.sessions.length - 1 ? `1px solid ${THEME.slate200}` : "none",
                        alignItems: "center",
                      }}
                    >
                      <div style={{ fontSize: 13, color: THEME.slate600, fontWeight: 600 }}>
                        {s.date}
                      </div>
                      <div
                        style={{
                          fontSize: 13,
                          fontWeight: 700,
                          color: VisualizationService.getRomColor(s.rom),
                        }}
                      >
                        {s.rom}%
                      </div>
                      <div>
                        <span
                          style={{
                            fontSize: 12,
                            background:
                              s.quality >= 85 ? THEME.greenLight : s.quality >= 65 ? THEME.tealLight : THEME.amberLight,
                            color:
                              s.quality >= 85 ? THEME.green : s.quality >= 65 ? THEME.tealDim : THEME.amberDim,
                            padding: "2px 8px",
                            borderRadius: 6,
                            fontWeight: 600,
                          }}
                        >
                          {isMobile && "Quality "}{s.quality}%
                        </span>
                      </div>
                      <div>
                        <span
                          style={{
                            fontSize: 12,
                            background:
                              s.fatigue >= 70 ? THEME.redLight : s.fatigue >= 45 ? THEME.amberLight : THEME.greenLight,
                            color:
                              s.fatigue >= 70 ? THEME.red : s.fatigue >= 45 ? THEME.amberDim : THEME.green,
                            padding: "2px 8px",
                            borderRadius: 6,
                            fontWeight: 600,
                          }}
                        >
                          {isMobile && "Fatigue "}{s.fatigue}%
                        </span>
                      </div>
                      <div
                        style={{
                          fontSize: 12,
                          color: THEME.slate500,
                          ...(isMobile && { gridColumn: "1 / -1" }),
                        }}
                      >
                        {s.exercise} × {s.reps}
                      </div>
                    </div>
                  ))}
                </>
              )}
            </Card>
          </div>
        ) : (
          <Card style={{ padding: "48px", textAlign: "center" }}>
            <div style={{ fontSize: 14, color: THEME.slate400 }}>
              Select a patient from the list to view their profile.
            </div>
          </Card>
        )}
      </div>
    </div>
  );
}

export default PatientsPage;
