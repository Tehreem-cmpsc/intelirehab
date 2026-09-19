import React from "react";

export default function RadialProgress({
  value,
  size = 64,
  stroke = 7,
  color = "var(--primary)",
  track = "var(--border)",
  label,
  labelColor,
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke={color}
        strokeWidth={stroke}
        strokeDasharray={c}
        strokeDashoffset={c - (value / 100) * c}
        strokeLinecap="round"
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
        style={{ transition: "stroke-dashoffset 1s cubic-bezier(.16,1,.3,1)" }}
      />
      {label !== undefined && (
        <text
          x="50%"
          y="52%"
          textAnchor="middle"
          dominantBaseline="middle"
          className="cp-display"
          fontSize={size * 0.24}
          fontWeight="700"
          fill={labelColor || "var(--ink)"}
        >
          {label}
        </text>
      )}
    </svg>
  );
}
