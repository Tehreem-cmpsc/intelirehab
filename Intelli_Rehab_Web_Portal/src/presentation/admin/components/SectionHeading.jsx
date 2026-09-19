import React from "react";

export default function SectionHeading({ eyebrow, title, action }) {
  return (
    <div className="flex items-end justify-between mb-6">
      <div>
        <div className="cp-mono text-[11px] tracking-widest text-[var(--primary)] mb-1.5">
          {eyebrow}
        </div>
        <h2 className="cp-display font-bold text-[22px] text-[var(--ink)]">{title}</h2>
      </div>
      {action}
    </div>
  );
}
