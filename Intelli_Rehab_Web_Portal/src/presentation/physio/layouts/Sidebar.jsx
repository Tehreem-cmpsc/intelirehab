import { THEME } from "../../../infrastructure/physio/constants";
import LogoFull from "../components/LogoFull";
import PatientUseCases from "../../../domain/physio/usecases/PatientUseCases";

const NAV = [
  { key: "dashboard", icon: "◻", label: "Dashboard" },
  { key: "patients", icon: "◻", label: "Patients" },
  { key: "approvals", icon: "◻", label: "Approvals" },
  { key: "atrisk", icon: "◻", label: "At Risk" },
  { key: "exercises", icon: "◻", label: "Exercise DB" },
];

function Sidebar({ page, setPage, onLogout, user, clinic }) {
  const pending = PatientUseCases.getPendingApprovalsCount();
  const atRisk = PatientUseCases.getAtRiskCount();
  const isDark = typeof document !== "undefined" && document.documentElement.getAttribute("data-theme") === "dark";

  return (
    <aside
      style={{
        width: 228,
        background: THEME.navy,
        display: "flex",
        flexDirection: "column",
        flexShrink: 0,
        fontFamily: "'Inter','Segoe UI',sans-serif",
      }}
    >
      <div
        style={{
          padding: "26px 20px 20px",
          borderBottom: `1px solid ${THEME.navyLight}`,
        }}
      >
        <LogoFull dark />
      </div>

      <nav style={{ flex: 1, padding: "14px 12px" }}>
        {NAV.map((n) => (
          <button
            key={n.key}
            onClick={() => setPage(n.key)}
            style={{
              display: "flex",
              alignItems: "center",
              width: "100%",
              padding: "10px 14px",
              borderRadius: 9,
              border: "none",
              cursor: "pointer",
              background: page === n.key ? THEME.teal : "transparent",
              color: page === n.key ? THEME.white : "rgba(255,255,255,0.82)",
              fontWeight: page === n.key ? 600 : 400,
              fontSize: 14,
              marginBottom: 2,
              textAlign: "left",
              transition: "all 0.15s",
            }}
          >
            {n.label}
            {n.key === "approvals" && pending > 0 && (
              <span
                style={{
                  marginLeft: "auto",
                  background: THEME.amber,
                  color: THEME.navy,
                  borderRadius: 10,
                  padding: "1px 7px",
                  fontSize: 11,
                  fontWeight: 700,
                }}
              >
                {pending}
              </span>
            )}
            {n.key === "atrisk" && atRisk > 0 && (
              <span
                style={{
                  marginLeft: "auto",
                  background: THEME.red,
                  color: THEME.white,
                  borderRadius: 10,
                  padding: "1px 7px",
                  fontSize: 11,
                  fontWeight: 700,
                }}
              >
                {atRisk}
              </span>
            )}
          </button>
        ))}
      </nav>

      <div
        style={{
          margin: "0 12px 20px",
          padding: 14,
          background: THEME.navyLight,
          borderRadius: 12,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
          <div
            style={{
              width: 38,
              height: 38,
              borderRadius: "50%",
              background: THEME.teal,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: THEME.white,
              fontWeight: 700,
              fontSize: 14,
              flexShrink: 0,
            }}
          >
            {user?.name ? user.name.split(" ").slice(1).map(n => n[0]).join("").slice(0, 2) : "AK"}
          </div>
          <div>
            <div style={{ color: "#FFFFFF", fontSize: 13, fontWeight: 600 }}>
              {user?.name ?? "Dr. Ahmed Khan"}
            </div>
            <div style={{ color: "rgba(255,255,255,0.88)", fontSize: 11 }}>
              {clinic?.name ?? "HealthCare Rehab"}
            </div>
          </div>
        </div>
        <button
          onClick={onLogout}
          style={{
            width: "100%",
            padding: "8px",
            background: "transparent",
            border: `1px solid rgba(255,255,255,0.18)`,
            borderRadius: 8,
            color: "rgba(255,255,255,0.92)",
            fontSize: 12,
            cursor: "pointer",
          }}
        >
          Sign out
        </button>
      </div>
    </aside>
  );
}

export default Sidebar;
