import { useEffect, useState } from "react";
import { THEME } from "../../../infrastructure/physio/constants";
import SessionUseCases from "../../../domain/physio/usecases/SessionUseCases";

const FATIGUE_LABELS = ["normal", "mild", "moderate", "critical"];

const ENDED_REASON_LABELS = {
  pain: "pain",
  tired: "too tired",
  band_problem: "band problem",
  other: "another reason",
};

// What the patient said about a session: their own 0-10 pain rating and, if it stopped early, why.
// Nothing is drawn for an older session that has neither.
export function SessionFeeling({ session }) {
  const { painLevel, endedReason } = session;
  if (painLevel == null && !endedReason) return null;
  const high = painLevel != null && painLevel >= 7;
  return (
    <span style={{ display: "inline-flex", flexWrap: "wrap", gap: 6 }}>
      {painLevel != null && (
        <span
          style={{
            fontSize: 12,
            fontWeight: 600,
            padding: "2px 8px",
            borderRadius: 6,
            background: high ? THEME.redLight : THEME.slate50,
            color: high ? THEME.red : THEME.slate600,
          }}
        >
          Pain {painLevel}/10
        </span>
      )}
      {endedReason && (
        <span
          style={{
            fontSize: 12,
            fontWeight: 600,
            padding: "2px 8px",
            borderRadius: 6,
            background: THEME.amberLight,
            color: THEME.amberDim,
          }}
        >
          Stopped early: {ENDED_REASON_LABELS[endedReason] ?? endedReason}
        </span>
      )}
    </span>
  );
}

// The set-by-set breakdown of one session, loaded when the physio opens it. A session with one set (or
// from an older app) has nothing to show, and says so.
export default function SessionSets({ sessionId }) {
  const [state, setState] = useState({ loading: true, sets: [], error: false });

  useEffect(() => {
    let cancelled = false;
    SessionUseCases.getSets(sessionId)
      .then((sets) => {
        if (!cancelled) setState({ loading: false, sets, error: false });
      })
      .catch(() => {
        if (!cancelled) setState({ loading: false, sets: [], error: true });
      });
    return () => {
      cancelled = true;
    };
  }, [sessionId]);

  const note = { fontSize: 12, color: THEME.slate400 };
  if (state.loading) return <div style={note}>Loading sets…</div>;
  if (state.error) return <div style={note}>Couldn't load the sets for this session.</div>;
  if (state.sets.length === 0) return <div style={note}>No set-by-set data for this session.</div>;

  return (
    <div style={{ display: "grid", gap: 6 }}>
      {state.sets.map((s) => {
        const prompts = s.corrections + s.unsafe;
        return (
          <div
            key={s.number}
            style={{
              display: "flex",
              flexWrap: "wrap",
              gap: "4px 14px",
              fontSize: 12.5,
              color: THEME.slate600,
              background: THEME.slate50,
              borderRadius: 8,
              padding: "8px 12px",
            }}
          >
            <strong style={{ color: THEME.slate800 }}>Set {s.number}</strong>
            <span>{s.reps} reps</span>
            <span>{s.rom ?? "—"}% ROM</span>
            <span>{prompts === 0 ? "no prompts" : `${prompts} prompt${prompts === 1 ? "" : "s"}`}</span>
            {s.unsafe > 0 && <span style={{ color: THEME.red, fontWeight: 600 }}>{s.unsafe} unsafe</span>}
            <span>{FATIGUE_LABELS[s.fatigue] ?? "—"} fatigue</span>
          </div>
        );
      })}
    </div>
  );
}
