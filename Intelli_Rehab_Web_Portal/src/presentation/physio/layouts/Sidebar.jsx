import { useState } from "react";
import {
  LayoutDashboard,
  Users,
  ShieldCheck,
  AlertTriangle,
  Dumbbell,
  ChevronLeft,
  ChevronRight,
  LogOut,
  X,
} from "lucide-react";
import { THEME } from "../../../infrastructure/physio/constants";
import LogoFull from "../components/LogoFull";
import Logo from "../components/Logo";

const NAV = [
  { key: "dashboard", icon: LayoutDashboard, label: "Dashboard" },
  { key: "patients", icon: Users, label: "Patients" },
  { key: "approvals", icon: ShieldCheck, label: "Approvals" },
  { key: "atrisk", icon: AlertTriangle, label: "At Risk" },
  { key: "exercises", icon: Dumbbell, label: "Exercises" },
];

// `mobile`: render as an off-canvas drawer (controlled by `open` /
// `onClose`) instead of a docked, collapsible column.
function Sidebar({ page, setPage, onLogout, user, clinic, patients = [], mobile = false, open = false, onClose }) {
  const [collapsedPref, setCollapsed] = useState(false);
  const collapsed = mobile ? false : collapsedPref;
  const pending = patients.filter((p) => p.isPendingApproval()).length;
  const atRisk = patients.filter((p) => p.isAtRisk()).length;

  return (
    <>
    {mobile && (
      <div
        onClick={onClose}
        aria-hidden="true"
        style={{
          position: "fixed",
          inset: 0,
          background: "rgba(4, 20, 23, 0.55)",
          opacity: open ? 1 : 0,
          pointerEvents: open ? "auto" : "none",
          transition: "opacity 0.25s ease",
          zIndex: 40,
        }}
      />
    )}
    <aside
      aria-hidden={mobile && !open ? true : undefined}
      style={{
        width: collapsed ? 72 : mobile ? 264 : 228,
        maxWidth: mobile ? "82vw" : undefined,
        background: THEME.navy,
        display: "flex",
        flexDirection: "column",
        flexShrink: 0,
        fontFamily: "'Inter','Segoe UI',sans-serif",
        transition: mobile ? "transform 0.28s cubic-bezier(.4,0,.2,1)" : "width 0.25s cubic-bezier(.4,0,.2,1)",
        overflow: "hidden",
        overflowY: "auto",
        ...(mobile && {
          position: "fixed",
          top: 0,
          bottom: 0,
          left: 0,
          zIndex: 50,
          transform: open ? "translateX(0)" : "translateX(-100%)",
          boxShadow: open ? "0 0 40px rgba(0,0,0,0.35)" : "none",
        }),
      }}
    >
      <div
        style={{
          padding: collapsed ? "20px 0" : "26px 20px 20px",
          borderBottom: `1px solid ${THEME.navyLight}`,
          display: "flex",
          alignItems: "center",
          justifyContent: collapsed ? "center" : "space-between",
          gap: 8,
        }}
      >
        {collapsed ? <Logo dark size={30} /> : <LogoFull dark />}
        {!collapsed && (
          <button
            onClick={() => (mobile ? onClose?.() : setCollapsed(true))}
            title={mobile ? "Close menu" : "Collapse sidebar"}
            aria-label={mobile ? "Close menu" : "Collapse sidebar"}
            style={{
              background: "rgba(255,255,255,0.08)",
              border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: 8,
              color: "rgba(255,255,255,0.7)",
              width: 26,
              height: 26,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              cursor: "pointer",
              flexShrink: 0,
            }}
          >
            {mobile ? <X size={14} /> : <ChevronLeft size={13} />}
          </button>
        )}
      </div>

      {collapsed && (
        <div style={{ display: "flex", justifyContent: "center", padding: "10px 0" }}>
          <button
            onClick={() => setCollapsed(false)}
            title="Expand sidebar"
            aria-label="Expand sidebar"
            style={{
              background: "rgba(255,255,255,0.08)",
              border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: 8,
              color: "rgba(255,255,255,0.7)",
              width: 26,
              height: 26,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              cursor: "pointer",
            }}
          >
            <ChevronRight size={13} />
          </button>
        </div>
      )}

      <nav style={{ flex: 1, padding: collapsed ? "8px 8px" : "14px 12px" }}>
        {NAV.map((n) => {
          const Icon = n.icon;
          const active = page === n.key;
          const badgeCount = n.key === "approvals" ? pending : n.key === "atrisk" ? atRisk : 0;
          return (
            <button
              key={n.key}
              onClick={() => setPage(n.key)}
              title={collapsed ? n.label : undefined}
              style={{
                position: "relative",
                display: "flex",
                alignItems: "center",
                width: "100%",
                padding: collapsed ? "10px" : "10px 14px",
                justifyContent: collapsed ? "center" : "flex-start",
                borderRadius: 9,
                border: "none",
                cursor: "pointer",
                background: active ? THEME.teal : "transparent",
                color: active ? THEME.onFill : "rgba(255,255,255,0.82)",
                fontWeight: active ? 600 : 400,
                fontSize: 14,
                marginBottom: 2,
                textAlign: "left",
                transition: "all 0.15s",
                gap: 10,
              }}
            >
              <Icon size={16} style={{ flexShrink: 0 }} />
              {!collapsed && <span style={{ flex: 1 }}>{n.label}</span>}
              {badgeCount > 0 && (
                <span
                  style={{
                    position: collapsed ? "absolute" : "static",
                    top: collapsed ? 4 : undefined,
                    right: collapsed ? 4 : undefined,
                    marginLeft: collapsed ? 0 : "auto",
                    background: n.key === "atrisk" ? THEME.red : THEME.amber,
                    color: n.key === "atrisk" ? THEME.onFill : THEME.navy,
                    borderRadius: 10,
                    padding: collapsed ? "1px 4px" : "1px 7px",
                    fontSize: 10,
                    fontWeight: 700,
                    minWidth: collapsed ? 14 : undefined,
                    textAlign: "center",
                  }}
                >
                  {badgeCount}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      <div
        style={{
          margin: collapsed ? "0 8px 16px" : "0 12px 20px",
          padding: collapsed ? 8 : 14,
          background: THEME.navyLight,
          borderRadius: 12,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: collapsed ? "center" : "flex-start",
            gap: 10,
            marginBottom: collapsed ? 8 : 12,
          }}
        >
          <div
            style={{
              width: 38,
              height: 38,
              borderRadius: "50%",
              background: THEME.teal,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: THEME.onFill,
              fontWeight: 700,
              fontSize: 14,
              flexShrink: 0,
            }}
            title={collapsed ? (user?.name ?? "Dr. Ahmed Khan") : undefined}
          >
            {user?.name ? user.name.split(" ").slice(1).map(n => n[0]).join("").slice(0, 2) : "AK"}
          </div>
          {!collapsed && (
            <div>
              <div style={{ color: "#FFFFFF", fontSize: 13, fontWeight: 600 }}>
                {user?.name ?? "Dr. Ahmed Khan"}
              </div>
              <div style={{ color: "rgba(255,255,255,0.88)", fontSize: 11 }}>
                {clinic?.name ?? "HealthCare Rehab"}
              </div>
            </div>
          )}
        </div>
        <button
          onClick={onLogout}
          title={collapsed ? "Sign out" : undefined}
          aria-label="Sign out"
          style={{
            width: "100%",
            padding: "8px",
            background: "transparent",
            border: `1px solid rgba(255,255,255,0.18)`,
            borderRadius: 8,
            color: "rgba(255,255,255,0.92)",
            fontSize: 12,
            cursor: "pointer",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 6,
          }}
        >
          <LogOut size={13} />
          {!collapsed && "Sign out"}
        </button>
      </div>
    </aside>
    </>
  );
}

export default Sidebar;
