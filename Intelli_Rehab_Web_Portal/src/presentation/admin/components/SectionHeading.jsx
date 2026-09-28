import React from "react";

export default function SectionHeading({ eyebrow, title, action }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
      <div className="min-w-0">
        <div className="cp-mono text-[11px] tracking-widest text-[var(--primary)] mb-1.5">
          {eyebrow}
        </div>
        <h2 className="cp-display font-bold text-[20px] sm:text-[22px] text-[var(--ink)]">{title}</h2>
      </div>
      {action}
    </div>
  );
}
