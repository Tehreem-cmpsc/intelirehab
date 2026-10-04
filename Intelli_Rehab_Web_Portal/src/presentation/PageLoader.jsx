// The one loading state for the whole portal: an arm bending at the elbow while the joint angle
// sweeps out and the biceps lights up, with an EMG trace running underneath. It only uses the
// theme's CSS variables, so it follows light and dark mode, and the motion stops for people who
// ask their system for reduced motion (see the cp-load-* rules in index.css).
//   fullScreen: before any shell exists (first load, login redirect).
//   otherwise:  inside a shell, where only the page area is waiting; the sidebar and header stay put.
const EMG_TRACE = "M10 112 H34 L40 98 L47 126 L54 104 L60 118 L66 110 H88 L94 94 L102 130 L109 102 L116 118 L122 110 H170";

function ArmAnimation() {
  return (
    <svg width="180" height="140" viewBox="0 0 180 140" aria-hidden="true" style={{ overflow: "visible" }}>
      {/* biceps, glowing as the arm bends */}
      <ellipse className="cp-load-muscle" cx="58" cy="60" rx="20" ry="7" fill="var(--accent)" />
      {/* angle swept by the forearm */}
      <path
        className="cp-load-arc"
        d="M128 70 A38 38 0 0 0 103.4 34.3"
        pathLength="100"
        fill="none"
        stroke="var(--accent)"
        strokeWidth="3"
        strokeLinecap="round"
        strokeDasharray="100"
      />
      {/* upper arm (fixed) */}
      <line x1="18" y1="70" x2="90" y2="70" stroke="var(--primary)" strokeWidth="11" strokeLinecap="round" />
      {/* forearm and hand (rotate about the elbow) */}
      <g className="cp-load-forearm">
        <line x1="90" y1="70" x2="152" y2="70" stroke="var(--primary)" strokeWidth="11" strokeLinecap="round" />
        <circle cx="156" cy="70" r="6" fill="var(--surface)" stroke="var(--primary)" strokeWidth="3" />
      </g>
      {/* elbow joint */}
      <circle className="cp-load-ring" cx="90" cy="70" r="11" fill="none" stroke="var(--primary)" strokeWidth="2" />
      <circle cx="90" cy="70" r="6.5" fill="var(--surface)" stroke="var(--primary)" strokeWidth="3" />
      {/* EMG trace with a pulse travelling along it */}
      <path d={EMG_TRACE} fill="none" stroke="var(--border)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      <path
        className="cp-load-pulse"
        d={EMG_TRACE}
        pathLength="200"
        fill="none"
        stroke="var(--primary)"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeDasharray="46 154"
      />
    </svg>
  );
}

export default function PageLoader({ fullScreen = false, label = "Loading" }) {
  const content = (
    <div
      role="status"
      aria-live="polite"
      style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6, color: "var(--muted)" }}
    >
      <ArmAnimation />
      <span className="cp-display" style={{ fontSize: 14, fontWeight: 600, letterSpacing: "0.02em" }}>
        {label}…
      </span>
    </div>
  );

  if (fullScreen) {
    return (
      <div className="cp-root" style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100dvh" }}>
        {content}
      </div>
    );
  }
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "50vh", padding: 24 }}>
      {content}
    </div>
  );
}
