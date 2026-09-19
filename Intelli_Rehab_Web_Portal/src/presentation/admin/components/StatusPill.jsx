import React from "react";

export default function StatusPill({ tone = "success", children }) {
  const map = {
    success: { bg: "var(--success-tint)", fg: "var(--success)" },
    alert: { bg: "var(--alert-tint)", fg: "var(--alert)" },
    muted: { bg: "var(--primary-tint)", fg: "var(--primary)" },
  };
  const c = map[tone];
  return (
    <span
      className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold"
      style={{ background: c.bg, color: c.fg }}
    >
      <span className="cp-status-dot" style={{ background: c.fg }} />
      {children}
    </span>
  );
}
