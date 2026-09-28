import React, { useState } from "react";
import { Plus, Search, Loader2, ChevronDown, AlertTriangle, ShieldCheck } from "lucide-react";
import SectionHeading from "../components/SectionHeading";
import StatusPill from "../components/StatusPill";
import AddPhysiotherapistModal from "../components/AddPhysiotherapistModal";
import usePhysiotherapists from "../../../domain/admin/usePhysiotherapists";
import usePatients from "../../../domain/admin/usePatients";
import useIsMobile from "../../useIsMobile";

const STATUS_TONE = { Active: "success", Pending: "muted", Rejected: "alert" };
const PATIENT_STATUS_TONE = { active: "success", recovered: "muted", "at-risk": "alert" };

export default function PhysiotherapistsPanel({ clinic }) {
  const { list, loading, addPhysiotherapist, removePhysiotherapist, approvePhysiotherapist } =
    usePhysiotherapists(clinic?.id);
  const { list: patients } = usePatients(clinic?.id);
  const [query, setQuery] = useState("");
  const [showAdd, setShowAdd] = useState(false);
  const [justAdded, setJustAdded] = useState(null);
  const [expanded, setExpanded] = useState(null); // physio id
  const [removingId, setRemovingId] = useState(null);
  const [approvingId, setApprovingId] = useState(null);
  const [statusMessage, setStatusMessage] = useState("");
  const isMobile = useIsMobile();
  const columns = "minmax(0,1.3fr) minmax(0,1fr) minmax(0,1fr) 80px 100px 44px";

  const filtered = list.filter((p) =>
    (p.name + p.specialization).toLowerCase().includes(query.toLowerCase())
  );

  const handleAdd = async (form) => {
    const created = await addPhysiotherapist(form);
    setShowAdd(false);
    setJustAdded(created.id);
    setStatusMessage(
      `${created.name} has been added. Share their password with them directly — they'll still need your approval before they can log in.`
    );
    setTimeout(() => setJustAdded(null), 2500);
    setTimeout(() => setStatusMessage(""), 4200);
  };

  const handleRemove = async (id) => {
    if (!window.confirm("Remove this physiotherapist from the clinic roster?")) return;
    setRemovingId(id);
    try {
      await removePhysiotherapist(id);
      if (expanded === id) setExpanded(null);
    } finally {
      setRemovingId(null);
    }
  };

  const handleApprove = async (pt) => {
    setApprovingId(pt.id);
    try {
      await approvePhysiotherapist(pt.id);
      setStatusMessage(`${pt.name} has been approved and can now log in.`);
      setTimeout(() => setStatusMessage(""), 3600);
    } catch (err) {
      window.alert(err.message || "Unable to approve physiotherapist.");
    } finally {
      setApprovingId(null);
    }
  };

  const toggleExpand = (id) => setExpanded(expanded === id ? null : id);

  const getPatientsFor = (physioId) =>
    patients.filter((p) => p.physio_id === physioId);

  return (
    <div>
      <SectionHeading
        eyebrow="ROSTER"
        title="Physiotherapists"
        action={
          <button
            onClick={() => setShowAdd(true)}
            className="cp-btn-primary cp-focus rounded-lg px-4 py-2.5 text-[13.5px] flex items-center gap-1.5 cursor-pointer"
          >
            <Plus size={15} /> Add physiotherapist
          </button>
        }
      />

      <div className="relative mb-5 sm:max-w-xs">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by name or specialization"
          className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[13.5px]"
        />
      </div>
      {statusMessage && (
        <div className="mb-4 rounded-2xl border border-[var(--success)] bg-[var(--success-tint)] px-4 py-3 text-[13px] text-[var(--success)]">
          {statusMessage}
        </div>
      )}

      <div className="cp-card rounded-2xl overflow-hidden text-[var(--ink)]">
        {loading ? (
          <div className="px-5 py-8 text-center text-[var(--muted)]">
            <Loader2 size={16} className="animate-spin inline mr-2" /> Loading roster…
          </div>
        ) : filtered.length === 0 ? (
          <div className="px-5 py-8 text-center text-[var(--muted)]">
            No physiotherapists match "{query}".
          </div>
        ) : (
          <div>
            {/* Table Header (desktop only — phones get stacked cards) */}
            {!isMobile && (
            <div
              className="grid gap-3 text-[12px] font-semibold tracking-wide text-[var(--muted)] border-b px-5 py-3"
              style={{ borderColor: "var(--border)", gridTemplateColumns: columns }}
            >
              <span>Name</span>
              <span>Specialization</span>
              <span>License</span>
              <span>Patients</span>
              <span>Status</span>
              <span />
            </div>
            )}

            {filtered.map((pt) => {
              const isExpanded = expanded === pt.id;
              const ptPatients = getPatientsFor(pt.id);

              return (
                <div key={pt.id} className="border-b last:border-0" style={{ borderColor: "var(--border)" }}>
                  {/* Physio Row */}
                  <div
                    className={`grid items-center cursor-pointer transition-colors ${isMobile ? "gap-x-3 gap-y-1.5 px-4 py-3.5" : "gap-3 px-5 py-3.5"}`}
                    style={{
                      gridTemplateColumns: isMobile ? "minmax(0,1fr) auto auto" : columns,
                      background: justAdded === pt.id
                        ? "var(--success-tint)"
                        : isExpanded
                        ? "var(--primary-tint)"
                        : undefined,
                    }}
                    onClick={() => toggleExpand(pt.id)}
                  >
                    <span className="font-semibold text-[13.5px] text-[var(--ink)] flex items-center gap-2 min-w-0">
                      {/* Avatar initials */}
                      <span
                        className="w-7 h-7 rounded-full flex items-center justify-center text-[11px] font-bold text-[var(--on-primary)] flex-shrink-0"
                        style={{ background: "var(--primary)" }}
                      >
                        {pt.name.split(" ").slice(1).map((n) => n[0]).join("").slice(0, 2)}
                      </span>
                      <span className="truncate">{pt.name}</span>
                    </span>
                    {isMobile ? (
                      <>
                        <span>
                          <StatusPill tone={STATUS_TONE[pt.status] || "muted"}>{pt.status}</StatusPill>
                        </span>
                        <span className="flex justify-end">
                          <ChevronDown
                            size={16}
                            className="text-[var(--muted)] transition-transform duration-250"
                            style={{ transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}
                          />
                        </span>
                        <span className="col-span-3 pl-9 text-[12.5px] text-[var(--muted)] leading-snug">
                          {[pt.specialization, pt.license].filter(Boolean).join(" · ")}
                          <span className="text-[var(--ink)]"> · {ptPatients.length} {ptPatients.length === 1 ? "patient" : "patients"}</span>
                        </span>
                      </>
                    ) : (
                    <>
                    <span className="text-[var(--muted)] text-[13px] min-w-0">{pt.specialization}</span>
                    <span className="cp-mono text-[12px] text-[var(--muted)] min-w-0 break-words">{pt.license}</span>
                    <span className="text-[var(--ink)] text-[13.5px]">
                      {ptPatients.length} <span className="text-[var(--muted)] text-[12px]">active</span>
                    </span>
                    <span>
                      <StatusPill tone={STATUS_TONE[pt.status] || "muted"}>{pt.status}</StatusPill>
                    </span>
                    <span className="flex justify-end">
                      <ChevronDown
                        size={16}
                        className="text-[var(--muted)] transition-transform duration-250"
                        style={{ transform: isExpanded ? "rotate(180deg)" : "rotate(0deg)" }}
                      />
                    </span>
                    </>
                    )}
                  </div>

                  {/* Inline Patient Drawer */}
                  <div
                    style={{
                      maxHeight: isExpanded ? "1600px" : "0",
                      overflow: "hidden",
                      transition: "max-height 0.35s cubic-bezier(.4,0,.2,1)",
                    }}
                  >
                    <div
                      className="px-4 sm:px-5 pb-4 pt-2"
                      style={{ background: "var(--bg)", borderTop: `1px solid var(--border)` }}
                    >
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 py-3">
                        {[
                          { label: "CNIC", value: pt.cnic },
                          { label: "Qualification", value: pt.qualification },
                          { label: "Experience", value: pt.yearsExperience != null ? `${pt.yearsExperience} yrs` : null },
                          { label: "Joined", value: pt.joiningDate },
                        ].map((f) => (
                          <div key={f.label}>
                            <div className="text-[11px] font-semibold uppercase tracking-wide text-[var(--muted)]">
                              {f.label}
                            </div>
                            <div className="text-[13px] text-[var(--ink)] mt-0.5 cp-mono break-words">{f.value || "—"}</div>
                          </div>
                        ))}
                      </div>

                      {ptPatients.length === 0 ? (
                        <p className="text-[13px] text-[var(--muted)] py-4 text-center italic">
                          No patients currently assigned to {pt.name.split(" ")[1]}.
                        </p>
                      ) : (
                        <>
                          <div className="text-[11px] font-bold tracking-widest text-[var(--primary)] cp-mono uppercase mb-3 mt-1">
                            Assigned Patients — {ptPatients.length}
                          </div>
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            {ptPatients.map((patient) => (
                              <div
                                key={patient.id}
                                className="rounded-xl flex items-center gap-4 p-4"
                                style={{
                                  background: "var(--surface)",
                                  border: "1px solid var(--border)",
                                }}
                              >
                                <span
                                  className="w-11 h-11 rounded-full flex items-center justify-center text-[13px] font-bold text-[var(--on-primary)] flex-shrink-0"
                                  style={{ background: "var(--primary)" }}
                                >
                                  {(patient.name || "?").split(" ").map((n) => n[0]).join("").slice(0, 2)}
                                </span>

                                {/* Patient Info */}
                                <div className="min-w-0 flex-1">
                                  <div className="font-semibold text-[13.5px] text-[var(--ink)] truncate">
                                    {patient.name}
                                  </div>
                                  <div className="text-[12px] text-[var(--muted)] mt-0.5 truncate">
                                    {[patient.injury, patient.injury_side].filter(Boolean).join(" · ") || "No injury on file"}
                                  </div>
                                  <div className="flex items-center gap-1.5 mt-2">
                                    <StatusPill tone={PATIENT_STATUS_TONE[patient.status] || "muted"}>
                                      {patient.status || "unknown"}
                                    </StatusPill>
                                    {patient.warning && (
                                      <span className="flex items-center gap-1 text-[11px] font-semibold text-[var(--alert)]">
                                        <AlertTriangle size={11} /> {patient.warning}
                                      </span>
                                    )}
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        </>
                      )}

                      <div className="flex flex-col sm:flex-row sm:justify-end gap-2 pt-4">
                        {pt.status === "Pending" && (
                          <button
                            type="button"
                            onClick={() => handleApprove(pt)}
                            disabled={approvingId === pt.id}
                            className="cp-btn-primary cp-focus rounded-lg px-3 py-2.5 text-[13px] font-semibold flex items-center justify-center gap-1.5"
                          >
                            <ShieldCheck size={14} />
                            {approvingId === pt.id ? "Approving..." : "Approve physiotherapist"}
                          </button>
                        )}
                        <button
                          type="button"
                          onClick={() => handleRemove(pt.id)}
                          disabled={removingId === pt.id}
                          className="cp-btn-secondary cp-focus rounded-lg px-3 py-2.5 text-[13px] font-semibold"
                          style={{
                            background: "rgba(217,98,72,0.08)",
                            color: "var(--alert)",
                            border: "1px solid rgba(217,98,72,0.18)",
                          }}
                        >
                          {removingId === pt.id ? "Removing..." : "Remove physiotherapist"}
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {showAdd && (
        <AddPhysiotherapistModal onClose={() => setShowAdd(false)} onSubmit={handleAdd} />
      )}
    </div>
  );
}
