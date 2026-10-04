import { useState, useEffect, useRef } from "react";
import {
  ResponsiveContainer,
  AreaChart,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  Area,
} from "recharts";
import { THEME } from "../../../infrastructure/physio/constants";
import { Card, SectionHead, RomBar, Badge, PatientDetails } from "../components";
import WearableStatus from "../components/WearableStatus";
import SessionUseCases from "../../../domain/physio/usecases/SessionUseCases";
import ExerciseUseCases from "../../../domain/physio/usecases/ExerciseUseCases";
import ExercisePlanUseCases from "../../../domain/physio/usecases/ExercisePlanUseCases";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";
import { tooltipProps, axisTick, pagePadding } from "../components/chartTheme";
import useIsMobile from "../../useIsMobile";
import useToast from "../../useToast";
import ErrorNotice from "../../ErrorNotice";

const FREQUENCIES = ["Daily", "Every other day", "3× per week", "Weekly"];
const emptyRow = () => ({ key: Math.random().toString(36).slice(2), exerciseId: "", sets: 3, reps: 10, romTarget: 70, frequency: "Daily" });

// A session is one or more exercises assigned together (rehabilitation_plans
// + one patient_exercise_plans row per exercise, all sharing that plan_id).
// Pre-filled from the patient's current active assignment so re-opening this
// reads as "edit what they have," not a blank form every time.
function AssignExerciseModal({ patient, catalogue, currentPlan, onClose, onAssign, saving, error }) {
  const [planName, setPlanName] = useState(currentPlan?.planName || "");
  const [rows, setRows] = useState(() => {
    if (currentPlan?.exercises?.length) {
      return currentPlan.exercises.map((ex) => ({
        key: ex.assignmentId,
        exerciseId: ex.exerciseId,
        sets: ex.sets,
        reps: ex.reps,
        romTarget: ex.romTarget ?? 70,
        frequency: ex.frequency || "Daily",
      }));
    }
    return [emptyRow()];
  });
  const surface = THEME.surface;
  const isMobile = useIsMobile();

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

  const updateRow = (key, patch) => setRows((prev) => prev.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  const addRow = () => setRows((prev) => [...prev, emptyRow()]);
  const removeRow = (key) => setRows((prev) => (prev.length > 1 ? prev.filter((r) => r.key !== key) : prev));

  const usedIds = new Set(rows.map((r) => r.exerciseId).filter(Boolean));
  const incomplete = rows.some((r) => !r.exerciseId);

  const handleSubmit = () => {
    if (incomplete || saving) return;
    onAssign({
      planName,
      exercises: rows.map((r) => ({
        exerciseId: r.exerciseId,
        sets: r.sets,
        reps: r.reps,
        romTarget: r.romTarget,
        frequency: r.frequency,
      })),
    });
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
          width: 640,
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

        <div style={{ marginBottom: 20 }}>
          <label style={{ fontSize: 12, fontWeight: 600, color: THEME.slate600, display: "block", marginBottom: 6 }}>
            SESSION NAME
          </label>
          <input
            value={planName}
            onChange={(e) => setPlanName(e.target.value)}
            placeholder="e.g. Week 3 — shoulder mobility"
            style={inp}
          />
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 14, marginBottom: 6 }}>
          {rows.map((row, i) => {
            const ex = catalogue.find((e) => e.id === row.exerciseId);
            return (
              <div
                key={row.key}
                style={{
                  border: `1px solid ${THEME.slate200}`,
                  borderRadius: 12,
                  padding: 14,
                  position: "relative",
                }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
                  <label style={{ fontSize: 12, fontWeight: 600, color: THEME.slate600 }}>EXERCISE {i + 1}</label>
                  {rows.length > 1 && (
                    <button
                      onClick={() => removeRow(row.key)}
                      aria-label="Remove exercise"
                      style={{
                        border: "none",
                        background: "none",
                        color: THEME.slate400,
                        cursor: "pointer",
                        fontSize: 16,
                        lineHeight: 1,
                        padding: 4,
                      }}
                    >
                      ×
                    </button>
                  )}
                </div>
                <select
                  value={row.exerciseId}
                  onChange={(e) => updateRow(row.key, { exerciseId: e.target.value })}
                  style={{ ...inp, marginBottom: ex ? 10 : 0 }}
                >
                  <option value="" disabled>
                    Select an exercise…
                  </option>
                  {catalogue.map((e) => (
                    <option key={e.id} value={e.id} disabled={usedIds.has(e.id) && e.id !== row.exerciseId}>
                      {e.name}
                    </option>
                  ))}
                </select>

                {ex && (
                  <div
                    style={{
                      background: THEME.tealLight,
                      borderRadius: 10,
                      padding: "10px 12px",
                      marginBottom: 12,
                    }}
                  >
                    <div style={{ fontSize: 12, fontWeight: 600, color: THEME.tealDim }}>
                      Target: {ex.target} · {ex.difficulty}
                    </div>
                    <div style={{ fontSize: 12, color: THEME.slate600, marginTop: 4 }}>{ex.desc}</div>
                  </div>
                )}

                <div style={{ display: "grid", gridTemplateColumns: "repeat(3, minmax(0, 1fr))", gap: 10, marginBottom: 10 }}>
                  {[
                    ["SETS", row.sets, "sets", 1, 6],
                    ["REPS", row.reps, "reps", 3, 20],
                    ["ROM TARGET (%)", row.romTarget, "romTarget", 20, 100],
                  ].map(([l, v, field, min, max]) => (
                    <div key={l}>
                      <label style={{ fontSize: 11, fontWeight: 600, color: THEME.slate600, display: "block", marginBottom: 4 }}>
                        {l}
                      </label>
                      <input
                        type="number"
                        min={min}
                        max={max}
                        value={v}
                        onChange={(e) => updateRow(row.key, { [field]: Number(e.target.value) })}
                        style={inp}
                      />
                    </div>
                  ))}
                </div>

                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: THEME.slate600, display: "block", marginBottom: 4 }}>
                    FREQUENCY
                  </label>
                  <select value={row.frequency} onChange={(e) => updateRow(row.key, { frequency: e.target.value })} style={inp}>
                    {FREQUENCIES.map((f) => (
                      <option key={f}>{f}</option>
                    ))}
                  </select>
                </div>
              </div>
            );
          })}
        </div>

        <button
          onClick={addRow}
          disabled={usedIds.size >= catalogue.length}
          style={{
            width: "100%",
            padding: "10px",
            marginTop: 14,
            marginBottom: 20,
            border: `1.5px dashed ${THEME.slate200}`,
            borderRadius: 10,
            background: "none",
            color: THEME.teal,
            fontWeight: 600,
            fontSize: 13,
            cursor: usedIds.size >= catalogue.length ? "not-allowed" : "pointer",
            opacity: usedIds.size >= catalogue.length ? 0.5 : 1,
          }}
        >
          + Add another exercise
        </button>

        {error && (
          <div style={{ fontSize: 13, color: THEME.red, marginBottom: 16 }}>{error}</div>
        )}

        <div style={{ display: "flex", gap: 10 }}>
          <button
            onClick={onClose}
            disabled={saving}
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
            onClick={handleSubmit}
            disabled={incomplete || saving}
            style={{
              flex: 2,
              padding: "12px",
              background: THEME.teal,
              border: "none",
              borderRadius: 10,
              color: THEME.onFill,
              fontWeight: 700,
              cursor: incomplete || saving ? "not-allowed" : "pointer",
              opacity: incomplete || saving ? 0.6 : 1,
            }}
          >
            {saving ? "Assigning…" : "Assign session"}
          </button>
        </div>
      </div>
    </div>
  );
}

function PatientsPage({ patients, selectedId, setSelectedId, currentPhysioId }) {
  const [showAssign, setShowAssign] = useState(false);
  const { toastNode, showToast } = useToast();
  const [loadError, setLoadError] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [emg, setEmg] = useState([]);
  const [emgLoading, setEmgLoading] = useState(false);
  const [activePlan, setActivePlan] = useState(null);
  const [planLoading, setPlanLoading] = useState(false);
  const [catalogue, setCatalogue] = useState([]);
  const [assignSaving, setAssignSaving] = useState(false);
  const [assignError, setAssignError] = useState(null);
  const selected = patients.find((p) => p.id === selectedId);

  // The exercise catalogue is the same handful of rows for every patient,
  // so it's loaded once for the whole page rather than per selection.
  useEffect(() => {
    ExerciseUseCases.getAllExercises()
      .then(setCatalogue)
      .catch(() => {
        setCatalogue([]);
        setLoadError("Couldn't load the exercise list, so assigning is unavailable.");
      });
  }, [reloadKey]);

  // Only the newest request may update the screen: selecting patient A then B quickly must not let
  // A's slower answer replace B's plan.
  const latestPlanRequest = useRef(0);
  const loadActivePlan = (patientId) => {
    const request = ++latestPlanRequest.current;
    const current = () => request === latestPlanRequest.current;
    setPlanLoading(true);
    return ExercisePlanUseCases.getActivePlan(patientId)
      .then((plan) => {
        if (current()) setActivePlan(plan);
      })
      .catch(() => {
        if (!current()) return;
        setActivePlan(null);
        setLoadError("Couldn't load this patient's exercise plan - it may exist but not be shown.");
      })
      .finally(() => {
        if (current()) setPlanLoading(false);
      });
  };

  // EMG and the active exercise plan are both per-patient — only needed
  // for whichever one is currently open, so both are fetched on demand
  // instead of bulk-loaded with the patient list.
  useEffect(() => {
    if (!selectedId) {
      latestPlanRequest.current += 1; // drop any plan still loading for the patient just closed
      setEmg([]);
      setActivePlan(null);
      setPlanLoading(false);
      return;
    }
    let cancelled = false;
    setLoadError(null);
    setEmgLoading(true);
    SessionUseCases.getLatestEmgForPatient(selectedId)
      .then((data) => {
        if (!cancelled) setEmg(data);
      })
      .catch(() => {
        if (cancelled) return;
        setEmg([]);
        setLoadError("Couldn't load this patient's EMG readings.");
      })
      .finally(() => {
        if (!cancelled) setEmgLoading(false);
      });
    loadActivePlan(selectedId);
    return () => {
      cancelled = true;
    };
  }, [selectedId, reloadKey]);


  const handleAssign = async ({ planName, exercises }) => {
    setAssignSaving(true);
    setAssignError(null);
    try {
      await ExercisePlanUseCases.assignSession({
        patientId: selectedId,
        physioId: currentPhysioId,
        planName,
        exercises,
      });
      await loadActivePlan(selectedId);
      setShowAssign(false);
      showToast(`Exercise session assigned to ${selected.name}`);
    } catch (err) {
      console.error("Error assigning exercise session:", err);
      setAssignError(err.message || "Couldn't assign this session. Please try again.");
    } finally {
      setAssignSaving(false);
    }
  };

  const approvedPatients = patients.filter((p) => p.approved);
  const isMobile = useIsMobile();
  // Phones get master → detail: the list, or one patient with a back link.
  const showList = !isMobile || !selected;
  const showDetail = !isMobile || selected;

  return (
    <div style={{ padding: pagePadding(isMobile), position: "relative" }}>
      {toastNode}
      <ErrorNotice message={loadError} onRetry={() => setReloadKey((k) => k + 1)} />
      {showAssign && selected && (
        <AssignExerciseModal
          patient={selected}
          catalogue={catalogue}
          currentPlan={activePlan}
          onClose={() => {
            setShowAssign(false);
            setAssignError(null);
          }}
          onAssign={handleAssign}
          saving={assignSaving}
          error={assignError}
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
                <WearableStatus patient={p} compact />
                <Badge status={p.status} />
              </div>
              <div style={{ marginTop: 8 }}>
                <RomBar value={p.rom} height={4} />
                {p.noRecentSessions && (
                  <div style={{ fontSize: 11, color: THEME.slate400, marginTop: 4 }}>
                    No sessions in the last 90 days
                  </div>
                )}
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
                      <WearableStatus patient={selected} />
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

            <Card style={{ padding: isMobile ? "18px 16px" : "20px 22px" }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800, marginBottom: 14 }}>
                Patient details
              </div>
              <PatientDetails patient={selected} currentPhysioId={currentPhysioId} />
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

            {/* Assigned exercise session — one or more exercises under the
                same active rehabilitation_plans row */}
            <Card style={{ padding: isMobile ? "18px 16px" : "20px 24px" }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800, marginBottom: 4 }}>
                {activePlan?.planName || "Current exercise session"}
              </div>
              {planLoading ? (
                <div style={{ fontSize: 13, color: THEME.slate400, padding: "12px 0" }}>Loading…</div>
              ) : !activePlan?.exercises?.length ? (
                <div style={{ fontSize: 13, color: THEME.slate400, padding: "8px 0 4px" }}>
                  No exercises assigned yet.
                </div>
              ) : (
                <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 10 }}>
                  {activePlan.exercises.map((ex, i) => (
                    <div
                      key={ex.assignmentId}
                      style={{
                        display: "flex",
                        flexWrap: "wrap",
                        gap: 16,
                        justifyContent: "space-between",
                        alignItems: "flex-start",
                        paddingBottom: 12,
                        borderBottom: i < activePlan.exercises.length - 1 ? `1px solid ${THEME.slate200}` : "none",
                      }}
                    >
                      <div>
                        <div style={{ fontSize: 16, fontWeight: 800, color: THEME.teal }}>{ex.name}</div>
                        <div style={{ fontSize: 13, color: THEME.slate500, marginTop: 2 }}>
                          {[ex.target, ex.difficulty].filter(Boolean).join(" · ")}
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
                          ["Sets", ex.sets],
                          ["Reps", ex.reps],
                          ["ROM target", ex.romTarget != null ? `${ex.romTarget}%` : "—"],
                          ["Frequency", ex.frequency || "—"],
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
                            <div style={{ fontSize: 18, fontWeight: 800, color: THEME.slate800 }}>{v}</div>
                            <div style={{ fontSize: 11, color: THEME.slate400 }}>{l}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </Card>

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
