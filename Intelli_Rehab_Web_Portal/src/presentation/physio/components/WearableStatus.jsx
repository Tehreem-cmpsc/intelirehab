import { THEME } from "../../../infrastructure/physio/constants";
import { wearableState } from "../../../domain/physio/utils/patientLabels";

function ago(iso) {
  if (!iso) return null;
  const secs = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
  if (secs < 60) return "just now";
  const mins = Math.round(secs / 60);
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs} h ago`;
  return `${Math.round(hrs / 24)} d ago`;
}

export default function WearableStatus({ patient, compact = false }) {
  const state = wearableState(patient);
  const color = state === "live" ? THEME.green : state === "offline" ? THEME.amberDim : THEME.slate400;
  const last = state === "offline" ? ago(patient.wearableLastSeen) : null;
  const label = {
    live: "Wearable connected · live",
    offline: "Paired · not connected",
    none: "No wearable",
  }[state];

  if (compact) {
    return (
      <span
        title={last ? `${label} (last seen ${last})` : label}
        aria-label={label}
        style={{
          width: 8,
          height: 8,
          borderRadius: "50%",
          display: "inline-block",
          flexShrink: 0,
          background: state === "none" ? "transparent" : color,
          border: `1.5px solid ${color}`,
        }}
      />
    );
  }

  return (
    <span style={{ fontSize: 12, color, display: "inline-flex", alignItems: "center", gap: 5 }} role="status">
      <span
        style={{
          width: 8,
          height: 8,
          borderRadius: "50%",
          background: state === "none" ? "transparent" : color,
          border: `1.5px solid ${color}`,
          boxShadow: state === "live" ? `0 0 0 3px ${color}33` : "none",
        }}
      />
      {label}
      {last && <span style={{ color: THEME.slate400 }}>· last seen {last}</span>}
    </span>
  );
}
