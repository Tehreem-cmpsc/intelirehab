import React from "react";
import { Loader2, TrendingUp } from "lucide-react";
import SectionHeading from "../components/SectionHeading";
import RadialProgress from "../components/RadialProgress";
import usePatients from "../../../domain/admin/usePatients";

export default function PatientsPanel() {
  const { list, loading } = usePatients();
  return (
    <div>
      <SectionHeading eyebrow="CLINIC-WIDE" title="Patients in recovery" />
      <p className="text-[13.5px] text-[var(--muted)] -mt-4 mb-6 max-w-lg">
        A read-only view across every physiotherapist at your clinic. Protocols and session
        detail are managed by each patient's assigned physiotherapist.
      </p>
      <div className="cp-card rounded-2xl overflow-hidden text-[var(--ink)]">
        <table className="w-full text-left text-[13.5px]">
          <thead>
            <tr className="border-b" style={{ borderColor: "var(--border)" }}>
              {["Patient", "Physiotherapist", "Joint / Injury", "Recovery", "Last session"].map((h) => (
                <th key={h} className="px-5 py-3 font-semibold text-[12px] tracking-wide text-[var(--muted)]">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={5} className="px-5 py-8 text-center text-[var(--muted)]">
                  <Loader2 size={16} className="animate-spin inline mr-2" /> Loading patients…
                </td>
              </tr>
            ) : (
              list.map((p) => (
                <tr key={p.id} className="border-b last:border-0" style={{ borderColor: "var(--border)" }}>
                  <td className="px-5 py-3.5 font-semibold text-[var(--ink)]">{p.name}</td>
                  <td className="px-5 py-3.5 text-[var(--muted)]">{p.physio}</td>
                  <td className="px-5 py-3.5 text-[var(--muted)]">{p.joint}</td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-2.5">
                      <RadialProgress
                        value={p.recovery}
                        size={30}
                        stroke={4}
                        color={p.trend === "Improving" ? "var(--success)" : "var(--accent)"}
                      />
                      <div>
                        <div className="font-semibold text-[var(--ink)]">{p.recovery}%</div>
                        <div className="text-[11.5px] text-[var(--muted)] flex items-center gap-1">
                          {p.trend === "Improving" && <TrendingUp size={11} />} {p.trend}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-5 py-3.5 text-[var(--muted)]">{p.lastSession}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
