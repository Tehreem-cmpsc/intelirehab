import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ResponsiveContainer, LineChart, Line, CartesianGrid, XAxis, YAxis, ReferenceLine, ReferenceDot } from "recharts";
import { Pause, Play, X } from "lucide-react";
import { THEME } from "../../../infrastructure/physio/constants";
import SessionUseCases from "../../../domain/physio/usecases/SessionUseCases";
import { chartPoints, formatClock, poseAt, repsAt, tierAt } from "../../../domain/physio/utils/motionReplay";
import { axisTick } from "./chartTheme";
import useIsMobile from "../../useIsMobile";

const SPEEDS = [0.5, 1, 2];
const TIER_LABEL = { normal: "Good form", needsCorrection: "Needs correction", unsafe: "Unsafe - stopped" };
const tierColor = (tier) => (tier === "unsafe" ? THEME.red : tier === "needsCorrection" ? THEME.amber : THEME.green);

// Replays one session the way the patient saw it: the 3D arm (the app's own scene, /twin/replay.html)
// and the elbow-angle chart move together, with every counted rep and every amber/red moment marked.
export default function SessionReplay({ session, patientName, onClose }) {
  const isMobile = useIsMobile();
  const [motion, setMotion] = useState(undefined); // undefined = loading, null = no recording
  const [error, setError] = useState(null);
  const [t, setT] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [twinReady, setTwinReady] = useState(false);
  const frameRef = useRef(null);
  const tRef = useRef(0);

  useEffect(() => {
    let alive = true;
    SessionUseCases.getMotion(session.id)
      .then((m) => alive && setMotion(m))
      .catch(() => alive && setError("Couldn't load this session's movement. Try again."));
    return () => {
      alive = false;
    };
  }, [session.id]);

  useEffect(() => {
    const onKey = (e) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const duration = motion ? motion.t[motion.t.length - 1] : 0;
  const points = useMemo(() => (motion ? chartPoints(motion) : []), [motion]);
  const repTimes = useMemo(() => (motion ? motion.events.filter((e) => e.type === "rep").map((e) => e.t) : []), [motion]);
  const tierMarks = useMemo(
    () =>
      motion
        ? motion.events
            .filter((e) => e.type === "tier" && e.tier !== "normal")
            .map((e) => ({ ...e, angle: poseAt(motion, e.t).angle }))
        : [],
    [motion]
  );

  // Playback clock.
  useEffect(() => {
    if (!playing || !motion) return;
    let raf = 0;
    let last = performance.now();
    const step = (now) => {
      const next = Math.min(duration, tRef.current + ((now - last) / 1000) * speed);
      last = now;
      tRef.current = next;
      setT(next);
      if (next >= duration) setPlaying(false);
      else raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [playing, speed, motion, duration]);

  const seek = useCallback(
    (value) => {
      const v = Math.min(duration, Math.max(0, value));
      tRef.current = v;
      setT(v);
    },
    [duration]
  );

  // The 3D page sets up its scene after loading; wait for its `twin` API to report ready.
  const onFrameLoad = () => {
    let tries = 0;
    const poll = () => {
      const twin = frameRef.current?.contentWindow?.twin;
      if (twin?.isReady?.()) setTwinReady(true);
      else if (tries++ < 100) setTimeout(poll, 150);
    };
    poll();
  };

  const pose = motion ? poseAt(motion, t) : { angle: 0, emg: 0 };
  const state = motion ? tierAt(motion.events, t) : { tier: "normal", message: null };
  const reps = motion ? repsAt(motion.events, t) : 0;

  // Drive the 3D arm from the same moment the chart shows.
  useEffect(() => {
    if (!twinReady) return;
    const twin = frameRef.current?.contentWindow?.twin;
    if (!twin) return;
    twin.setElbow(pose.angle);
    twin.setEmg(pose.emg, 0);
    twin.setTier(state.tier);
  }, [twinReady, pose.angle, pose.emg, state.tier]);

  const togglePlay = () => {
    if (!motion) return;
    if (t >= duration) seek(0);
    setPlaying((p) => !p);
  };

  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(4, 20, 23, 0.6)",
        zIndex: 300,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: isMobile ? 8 : 24,
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={`Session replay for ${patientName}`}
        onClick={(e) => e.stopPropagation()}
        style={{
          background: THEME.surface,
          color: THEME.slate800,
          borderRadius: 18,
          width: "100%",
          maxWidth: 980,
          maxHeight: "100%",
          overflowY: "auto",
          boxShadow: "0 24px 60px rgba(0,0,0,0.35)",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", padding: "16px 20px", borderBottom: `1px solid ${THEME.slate200}` }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 16, fontWeight: 800 }}>Session replay</div>
            <div style={{ fontSize: 12.5, color: THEME.slate400, marginTop: 2 }}>
              {patientName} · {session.exercise} · {session.date}
            </div>
          </div>
          <button
            onClick={onClose}
            aria-label="Close replay"
            style={{ border: 0, background: THEME.slate100, color: THEME.slate800, borderRadius: 10, width: 36, height: 36, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
          >
            <X size={18} />
          </button>
        </div>

        {motion === undefined && !error && <Message text="Loading the movement…" />}
        {error && <Message text={error} />}
        {motion === null && (
          <Message text="No movement recording for this session. Sessions recorded with an older app version, or before the replay was set up, have none." />
        )}

        {motion && (
          <div style={{ padding: isMobile ? 14 : 20 }}>
            <div style={{ display: "grid", gridTemplateColumns: isMobile ? "1fr" : "320px 1fr", gap: 20, alignItems: "start" }}>
              {/* 3D arm */}
              <div style={{ background: THEME.slate50, borderRadius: 14, position: "relative", aspectRatio: "1 / 1" }}>
                <iframe
                  ref={frameRef}
                  title="3D arm replay"
                  src={`/twin/replay.html?side=${motion.side}`}
                  onLoad={onFrameLoad}
                  style={{ border: 0, width: "100%", height: "100%", borderRadius: 14, pointerEvents: "none" }}
                />
                {!twinReady && (
                  <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 12.5, color: THEME.slate400 }}>
                    Loading the 3D arm…
                  </div>
                )}
              </div>

              {/* Readout + chart */}
              <div style={{ minWidth: 0 }}>
                <div style={{ display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: 10, marginBottom: 14 }}>
                  <Stat label="Elbow" value={`${Math.round(pose.angle)}°`} />
                  <Stat label="Muscle" value={`${Math.round(pose.emg)}%`} />
                  <Stat label="Reps" value={`${reps}`} />
                  <Stat label="Time" value={`${formatClock(t)} / ${formatClock(duration)}`} />
                </div>
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                    fontSize: 12.5,
                    fontWeight: 700,
                    color: tierColor(state.tier),
                    marginBottom: 8,
                  }}
                >
                  <span style={{ width: 9, height: 9, borderRadius: 9, background: tierColor(state.tier) }} />
                  {TIER_LABEL[state.tier] ?? state.tier}
                  {state.message && <span style={{ fontWeight: 500, color: THEME.slate500 }}>· {state.message}</span>}
                </div>
                <div style={{ height: 220 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart
                      data={points}
                      margin={{ top: 8, right: 10, bottom: 0, left: -18 }}
                      onClick={(e) => e && e.activeLabel != null && seek(Number(e.activeLabel))}
                    >
                      <CartesianGrid strokeDasharray="3 3" stroke={THEME.slate200} />
                      <XAxis
                        dataKey="t"
                        type="number"
                        domain={[0, duration]}
                        tickFormatter={(v) => formatClock(v)}
                        tick={axisTick()}
                        axisLine={false}
                        tickLine={false}
                      />
                      <YAxis tick={axisTick()} axisLine={false} tickLine={false} unit="°" domain={[0, "auto"]} />
                      {repTimes.map((rt, i) => (
                        <ReferenceLine key={`r${i}`} x={rt} stroke={THEME.teal} strokeDasharray="2 4" strokeOpacity={0.6} />
                      ))}
                      <Line type="monotone" dataKey="angle" stroke={THEME.teal} strokeWidth={2} dot={false} isAnimationActive={false} />
                      {tierMarks.map((m, i) => (
                        <ReferenceDot key={`m${i}`} x={m.t} y={m.angle} r={5} fill={tierColor(m.tier)} stroke="none" />
                      ))}
                      <ReferenceLine x={t} stroke={THEME.slate800} strokeWidth={1.5} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
                <div style={{ fontSize: 11.5, color: THEME.slate400, marginTop: 4 }}>
                  Dashed lines: counted reps. Dots: amber (needs correction) and red (unsafe) moments. Click the chart to jump there.
                </div>

                {/* Controls */}
                <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 14 }}>
                  <button
                    onClick={togglePlay}
                    aria-label={playing ? "Pause" : "Play"}
                    style={{ border: 0, background: THEME.teal, color: THEME.onFill, borderRadius: 12, width: 42, height: 42, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}
                  >
                    {playing ? <Pause size={18} /> : <Play size={18} />}
                  </button>
                  <input
                    type="range"
                    aria-label="Replay position"
                    min={0}
                    max={duration}
                    step={0.05}
                    value={t}
                    onChange={(e) => seek(Number(e.target.value))}
                    style={{ flex: 1, accentColor: THEME.teal }}
                  />
                  <div style={{ display: "flex", gap: 4 }}>
                    {SPEEDS.map((s) => (
                      <button
                        key={s}
                        onClick={() => setSpeed(s)}
                        style={{
                          border: `1px solid ${s === speed ? THEME.teal : THEME.slate200}`,
                          background: s === speed ? THEME.tealLight : "transparent",
                          color: s === speed ? THEME.tealDim : THEME.slate500,
                          borderRadius: 8,
                          padding: "5px 8px",
                          fontSize: 12,
                          fontWeight: 700,
                          cursor: "pointer",
                        }}
                      >
                        {s}×
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value }) {
  return (
    <div style={{ background: THEME.slate50, borderRadius: 10, padding: "8px 10px", minWidth: 0 }}>
      <div style={{ fontSize: 11, color: THEME.slate400, fontWeight: 600 }}>{label}</div>
      <div style={{ fontSize: 15, fontWeight: 800, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{value}</div>
    </div>
  );
}

function Message({ text }) {
  return <div style={{ padding: "40px 24px", textAlign: "center", fontSize: 13.5, color: THEME.slate400 }}>{text}</div>;
}
