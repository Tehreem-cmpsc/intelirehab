import React from "react";
import { Loader2, AlertTriangle } from "lucide-react";
import SectionHeading from "../components/SectionHeading";
import StatusPill from "../components/StatusPill";
import usePatients from "../../../domain/admin/usePatients";

const STATUS_TONE = { active: "success", recovered: "muted", "at-risk": "alert" };

export default function PatientsPanel({ clinic }) {
  const { list, loading } = usePatients(clinic?.id);
  return (
    <div>
      <SectionHeading eyebrow="CLINIC-WIDE" title="Patients in recovery" />
      <p className="text-[13.5px] text-[var(--muted)] -mt-4 mb-6 max-w-lg">
        A read-only view across every physiotherapist at your clinic. Protocols and session
        detail are managed by each patient's assigned physiotherapist.
      </p>
      <div className="cp-card rounded-2xl overflow-x-auto text-[var(--ink)]">
        <table className="w-full min-w-[640px] text-left text-[13.5px]">
          <thead>
            <tr className="border-b" style={{ borderColor: "var(--border)" }}>
              {["Patient", "Physiotherapist", "Injury", "Status", "Added"].map((h) => (
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
            ) : list.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-5 py-8 text-center text-[var(--muted)]">
                  No patients yet.
                </td>
              </tr>
            ) : (
              list.map((p) => (
                <tr key={p.id} className="border-b last:border-0" style={{ borderColor: "var(--border)" }}>
                  <td className="px-5 py-3.5 font-semibold text-[var(--ink)]">{p.name}</td>
                  <td className="px-5 py-3.5 text-[var(--muted)]">
                    {p.physiotherapists?.full_name ?? "Unassigned"}
                  </td>
                  <td className="px-5 py-3.5 text-[var(--muted)]">
                    {[p.injury, p.injury_side].filter(Boolean).join(" · ") || "—"}
                  </td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-1.5">
                      <StatusPill tone={STATUS_TONE[p.status] || "muted"}>{p.status || "unknown"}</StatusPill>
                      {p.warning && (
                        <span className="flex items-center gap-1 text-[11px] font-semibold text-[var(--alert)]">
                          <AlertTriangle size={11} />
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-5 py-3.5 text-[var(--muted)]">
                    {p.created_at ? new Date(p.created_at).toLocaleDateString() : "—"}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
