import React from "react";
import { Loader2, Clock } from "lucide-react";
import SectionHeading from "../components/SectionHeading";
import RadialProgress from "../components/RadialProgress";
import useDashboardStats from "../../../domain/admin/useDashboardStats";

export default function OverviewPanel({ user, clinic }) {
  const stats = useDashboardStats(clinic?.id);
  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";

  return (
    <div>
      <SectionHeading eyebrow="OVERVIEW" title={`${greeting}, ${user?.name?.split(" ")[0]}`} />
      {!stats ? (
        <div className="text-[var(--muted)] text-sm flex items-center gap-2">
          <Loader2 size={15} className="animate-spin" /> Loading your clinic's numbers…
        </div>
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-10">
          {[
            { label: "Physiotherapists", value: stats.physios, color: "var(--primary)", suffix: "" },
            { label: "Patients in recovery", value: stats.patients, color: "var(--accent)", suffix: "" },
            { label: "Sessions today", value: stats.sessionsToday, color: "var(--success)", suffix: "" },
            { label: "Avg. ROM recovery", value: stats.avgRom, color: "var(--primary)", suffix: "%" },
          ].map((s) => (
            <div key={s.label} className="cp-card cp-card-hover rounded-2xl p-5 text-[var(--ink)]">
              <RadialProgress
                value={s.value == null ? 0 : s.suffix ? s.value : Math.min(100, s.value * 8)}
                size={46}
                stroke={5}
                color={s.color}
              />
              <div className="cp-display font-bold text-[26px] mt-3 text-[var(--ink)]">
                {s.value == null ? "—" : `${s.value}${s.suffix}`}
              </div>
              <div className="text-[13px] text-[var(--muted)] mt-0.5">{s.label}</div>
            </div>
          ))}
        </div>
      )}

      <div className="cp-card rounded-2xl overflow-hidden text-[var(--ink)]">
        <div className="px-5 py-4 border-b flex items-center gap-2" style={{ borderColor: "var(--border)" }}>
          <Clock size={15} className="text-[var(--primary)]" />
          <span className="font-semibold text-[14px] text-[var(--ink)]">Recent activity</span>
        </div>
        <div className="px-5 py-8 text-center text-[13.5px] text-[var(--muted)]">
          Activity tracking isn't set up yet — nothing to show here.
        </div>
      </div>
    </div>
  );
}
