import { useState } from "react";
import { THEME } from "../../../infrastructure/physio/constants";
import PatientUseCases from "../../../domain/physio/usecases/PatientUseCases";
import Card from "./Card";

// The built-in limits the patient's app uses when nothing is set here (see SafetyLimits and
// LiveSession in the mobile app).
const DEFAULT_ANGLE = 160;
const DEFAULT_SPEED = 300;

// The red "stop now" limits for one patient. Left blank, the app uses its built-in defaults. These
// end the patient's session the moment they are exceeded, so they are set deliberately: a blank field
// is "use the default", not "no limit".
export default function SafetyLimitsCard({ patient, showToast, isMobile }) {
  // What is saved, kept here so the Save button settles right after saving, without waiting for the
  // portal's next refresh. The page keys this card by patient, so it starts fresh for each one.
  const [current, setCurrent] = useState(patient.safetyLimits);
  const [angle, setAngle] = useState(current.maxAngleDeg ?? "");
  const [speed, setSpeed] = useState(current.maxSpeedDegPerSec ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const dirty =
    String(angle) !== String(current.maxAngleDeg ?? "") || String(speed) !== String(current.maxSpeedDegPerSec ?? "");

  const save = async () => {
    setSaving(true);
    setError(null);
    try {
      const saved = await PatientUseCases.setSafetyLimits(patient.id, { maxAngleDeg: angle, maxSpeedDegPerSec: speed });
      setCurrent(saved);
      setAngle(saved.maxAngleDeg ?? "");
      setSpeed(saved.maxSpeedDegPerSec ?? "");
      showToast("Safety limits saved. They apply from the patient's next session.");
    } catch (err) {
      setError(err.message || "Couldn't save the safety limits. Try again.");
    } finally {
      setSaving(false);
    }
  };

  const input = {
    width: "100%",
    boxSizing: "border-box",
    padding: "9px 12px",
    border: `1.5px solid ${THEME.slate200}`,
    borderRadius: 9,
    fontSize: 13,
    color: THEME.slate800,
    background: THEME.slate50,
    outline: "none",
  };
  const label = { fontSize: 12, fontWeight: 600, color: THEME.slate600, marginBottom: 4, display: "block" };

  return (
    <Card style={{ padding: isMobile ? "18px 16px" : "20px 22px" }}>
      <div style={{ fontSize: 14, fontWeight: 700, color: THEME.slate800, marginBottom: 4 }}>
        Safety limits (red stop)
      </div>
      <div style={{ fontSize: 12.5, color: THEME.slate500, marginBottom: 14, lineHeight: 1.5 }}>
        The session pauses and asks the patient to reset when their elbow goes past the angle, or moves faster
        than the speed, for a moment. Leave a field blank to use the app's default.
      </div>
      <div style={{ display: "grid", gridTemplateColumns: isMobile ? "1fr" : "1fr 1fr", gap: 12 }}>
        <label>
          <span style={label}>Maximum angle (°) — default {DEFAULT_ANGLE}</span>
          <input
            type="number"
            inputMode="numeric"
            min={60}
            max={180}
            step={1}
            placeholder={String(DEFAULT_ANGLE)}
            value={angle}
            onChange={(e) => setAngle(e.target.value)}
            style={input}
          />
        </label>
        <label>
          <span style={label}>Maximum speed (°/s) — default {DEFAULT_SPEED}</span>
          <input
            type="number"
            inputMode="numeric"
            min={60}
            max={1000}
            step={10}
            placeholder={String(DEFAULT_SPEED)}
            value={speed}
            onChange={(e) => setSpeed(e.target.value)}
            style={input}
          />
        </label>
      </div>
      {error && (
        <div role="alert" style={{ marginTop: 10, fontSize: 12.5, color: THEME.red, fontWeight: 600 }}>
          {error}
        </div>
      )}
      <div style={{ marginTop: 14 }}>
        <button
          onClick={save}
          disabled={!dirty || saving}
          style={{
            padding: "9px 18px",
            background: dirty && !saving ? THEME.teal : THEME.slate200,
            border: "none",
            borderRadius: 10,
            color: dirty && !saving ? THEME.onFill : THEME.slate400,
            fontWeight: 700,
            fontSize: 13,
            cursor: dirty && !saving ? "pointer" : "default",
          }}
        >
          {saving ? "Saving…" : "Save limits"}
        </button>
      </div>
    </Card>
  );
}
