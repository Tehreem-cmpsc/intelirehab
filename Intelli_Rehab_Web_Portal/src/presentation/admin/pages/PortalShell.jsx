import React, { useEffect, useState } from "react";
import { LogOut, LayoutGrid, Users, HeartPulse, Building2, ChevronLeft, ChevronRight, Sun, Moon, Menu, X } from "lucide-react";
import Logo, { LogoIcon } from "../components/Logo";
import useIsMobile from "../../useIsMobile";

const NAV_ITEMS = [
  { id: "overview",  label: "Dashboard",          icon: LayoutGrid },
  { id: "physios",   label: "Physiotherapists",   icon: Users },
  { id: "patients",  label: "Patients",           icon: HeartPulse },
  { id: "profile",   label: "Clinic Profile",     icon: Building2 },
];

// Clinic-admin frame. On narrow screens the sidebar becomes a slide-in
// drawer opened from the header's menu button.
export default function PortalShell({ user, clinic, activeTab, setActiveTab, onLogout, dark, setDark, children }) {
  const isMobile = useIsMobile();
  const [collapsedPref, setCollapsed] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const collapsed = isMobile ? false : collapsedPref;

  useEffect(() => {
    if (!isMobile) setDrawerOpen(false);
  }, [isMobile]);

  const initials = user?.name?.split(" ").map((p) => p[0]).join("").slice(0, 2) ?? "A";

  // Sidebar colours stay dark in both themes; the main area follows the
  // .cp-root tokens (which index.css swaps for dark mode).
  const s = {
    sidebarBg:   dark ? "#0b2428" : "#093D42",
    sidebarBorder: "rgba(255,255,255,0.06)",
    badgeBg:     dark ? "rgba(255,255,255,0.06)" : "rgba(255,255,255,0.05)",
    badgeBorder: "rgba(255,255,255,0.08)",
    activeNavBg: "rgba(49, 232, 198, 0.12)",
    activeNavColor: "#31E8C6",
    mutedNavColor: "rgba(255,255,255,0.72)",
    footerBorder: "rgba(255,255,255,0.07)",
  };

  const selectTab = (id) => {
    setActiveTab(id);
    setDrawerOpen(false);
  };

  const sidebarIconButton = {
    background: "rgba(255,255,255,0.08)", border: "1px solid rgba(255,255,255,0.12)",
    borderRadius: "8px", color: "rgba(255,255,255,0.8)",
    width: "28px", height: "28px", display: "flex", alignItems: "center",
    justifyContent: "center", cursor: "pointer", flexShrink: 0, transition: "background 0.15s",
  };

  return (
    <div style={{ display: "flex", minHeight: "100dvh", background: "var(--bg)", transition: "background 0.25s ease" }}
         data-theme={dark ? "dark" : "light"}
         className="cp-root">

      {isMobile && (
        <div
          onClick={() => setDrawerOpen(false)}
          aria-hidden="true"
          style={{
            position: "fixed", inset: 0, background: "rgba(4, 20, 23, 0.55)", zIndex: 40,
            opacity: drawerOpen ? 1 : 0, pointerEvents: drawerOpen ? "auto" : "none",
            transition: "opacity 0.25s ease",
          }}
        />
      )}

      {/* ── Sidebar ── */}
      <aside
        aria-hidden={isMobile && !drawerOpen ? true : undefined}
        style={{
          width: collapsed ? "72px" : isMobile ? "272px" : "240px",
          maxWidth: isMobile ? "84vw" : undefined,
          height: "100dvh",
          background: s.sidebarBg,
          borderRight: `1px solid ${s.sidebarBorder}`,
          display: "flex", flexDirection: "column", flexShrink: 0,
          overflowX: "hidden", overflowY: "auto",
          ...(isMobile
            ? {
                position: "fixed", top: 0, left: 0, zIndex: 50,
                transform: drawerOpen ? "translateX(0)" : "translateX(-100%)",
                transition: "transform 0.28s cubic-bezier(.4,0,.2,1)",
                boxShadow: drawerOpen ? "0 0 40px rgba(0,0,0,0.35)" : "none",
              }
            : {
                position: "sticky", top: 0,
                transition: "width 0.25s cubic-bezier(.4,0,.2,1), background 0.25s ease",
              }),
        }}
      >

        {/* Sidebar Header */}
        <div style={{
          padding: collapsed ? "20px 0" : "20px 20px",
          display: "flex", alignItems: "center",
          justifyContent: collapsed ? "center" : "space-between",
          borderBottom: `1px solid ${s.sidebarBorder}`,
          minHeight: "72px", gap: "8px",
        }}>
          {collapsed ? <LogoIcon size={32} light /> : <Logo size={30} light showText onDark />}
          <button
            onClick={() => (isMobile ? setDrawerOpen(false) : setCollapsed(!collapsedPref))}
            style={sidebarIconButton}
            aria-label={isMobile ? "Close menu" : collapsed ? "Expand sidebar" : "Collapse sidebar"}
            onMouseEnter={e => e.currentTarget.style.background = "rgba(255,255,255,0.15)"}
            onMouseLeave={e => e.currentTarget.style.background = "rgba(255,255,255,0.08)"}
          >
            {isMobile ? <X size={14} /> : collapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
          </button>
        </div>

        {/* Clinic Badge */}
        {!collapsed && (
          <div style={{
            margin: "14px 16px", padding: "8px 12px",
            background: s.badgeBg, border: `1px solid ${s.badgeBorder}`, borderRadius: "10px",
          }}>
            <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.6)", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.1em" }}>Active Clinic</div>
            <div style={{ fontSize: "12px", color: "rgba(255,255,255,0.9)", fontWeight: 600, marginTop: "2px", lineHeight: 1.3 }}>{clinic?.name ?? "—"}</div>
          </div>
        )}

        {/* Navigation */}
        <nav style={{ padding: collapsed ? "8px 8px" : "8px 10px", flex: 1, display: "flex", flexDirection: "column", gap: "3px" }}>
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const active = activeTab === item.id;
            return (
              <button key={item.id} onClick={() => selectTab(item.id)}
                title={collapsed ? item.label : undefined}
                style={{
                  display: "flex", alignItems: "center", gap: "11px",
                  padding: collapsed ? "10px" : isMobile ? "12px" : "10px 12px",
                  justifyContent: collapsed ? "center" : "flex-start",
                  borderRadius: "10px", border: "none", cursor: "pointer",
                  transition: "background 0.15s, color 0.15s",
                  background: active ? s.activeNavBg : "transparent",
                  color: active ? s.activeNavColor : s.mutedNavColor,
                  fontWeight: active ? 700 : 500, fontSize: "13.5px",
                  width: "100%", textAlign: "left", whiteSpace: "nowrap",
                  outline: "none", position: "relative",
                }}
                onMouseEnter={e => { if (!active) { e.currentTarget.style.background = "rgba(255,255,255,0.06)"; e.currentTarget.style.color = "rgba(255,255,255,0.92)"; }}}
                onMouseLeave={e => { if (!active) { e.currentTarget.style.background = "transparent"; e.currentTarget.style.color = s.mutedNavColor; }}}
              >
                {active && <span style={{ position: "absolute", left: 0, top: "20%", bottom: "20%", width: "3px", borderRadius: "3px", background: s.activeNavColor }} />}
                <Icon size={17} style={{ flexShrink: 0 }} />
                {!collapsed && <span>{item.label}</span>}
              </button>
            );
          })}
        </nav>

        {/* User Profile Footer */}
        <div style={{
          padding: collapsed ? "14px 8px" : "14px 12px",
          borderTop: `1px solid ${s.footerBorder}`,
          display: "flex", alignItems: "center", gap: "10px",
          justifyContent: collapsed ? "center" : "space-between",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: "10px", overflow: "hidden" }}>
            <div style={{
              width: "34px", height: "34px", borderRadius: "50%",
              background: "linear-gradient(135deg, #31E8C6, #0D6E76)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontFamily: "'Space Grotesk', sans-serif", fontWeight: 700,
              fontSize: "12px", color: "#fff", flexShrink: 0,
            }}>
              {initials}
            </div>
            {!collapsed && (
              <div style={{ overflow: "hidden" }}>
                <div style={{ fontSize: "12px", fontWeight: 700, color: "rgba(255,255,255,0.95)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{user?.name}</div>
                <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.72)", marginTop: "1px", whiteSpace: "nowrap" }}>{user?.role ?? "Clinic administrator"}</div>
              </div>
            )}
          </div>
          {!collapsed && (
            <button onClick={onLogout} title="Log out"
              style={{
                background: "transparent", border: "1px solid rgba(255,255,255,0.14)",
                borderRadius: "8px", color: "rgba(255,255,255,0.7)",
                padding: "6px", cursor: "pointer", display: "flex",
                alignItems: "center", justifyContent: "center",
                transition: "background 0.15s, color 0.15s", flexShrink: 0,
              }}
              onMouseEnter={e => { e.currentTarget.style.background = "rgba(217,98,72,0.15)"; e.currentTarget.style.color = "#F08070"; }}
              onMouseLeave={e => { e.currentTarget.style.background = "transparent"; e.currentTarget.style.color = "rgba(255,255,255,0.7)"; }}
              aria-label="Log out"
            >
              <LogOut size={15} />
            </button>
          )}
        </div>
      </aside>

      {/* ── Main Content ── */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0, minHeight: "100dvh" }}>

        {/* Top Header Bar */}
        <header style={{
          background: "var(--surface)", borderBottom: "1px solid var(--border)",
          padding: isMobile ? "12px 16px" : "14px 28px", display: "flex", alignItems: "center",
          gap: "12px", position: "sticky", top: 0, zIndex: 10,
          transition: "background 0.25s ease, border-color 0.25s ease",
        }}>
          {isMobile && (
            <HeaderButton label="Open menu" onClick={() => setDrawerOpen(true)}>
              <Menu size={18} />
            </HeaderButton>
          )}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="cp-display font-bold text-[16px] truncate" style={{ color: "var(--ink)" }}>
              {NAV_ITEMS.find(t => t.id === activeTab)?.label ?? "Dashboard"}
            </div>
            <div className="truncate" style={{ fontSize: "12px", color: "var(--muted)", marginTop: "1px" }}>
              {new Date().toLocaleDateString("en-PK", {
                weekday: isMobile ? "short" : "long", year: "numeric",
                month: isMobile ? "short" : "long", day: "numeric",
              })}
            </div>
          </div>

          <HeaderButton label={dark ? "Switch to light mode" : "Switch to dark mode"} onClick={() => setDark(!dark)}>
            {dark ? <Sun size={18} /> : <Moon size={18} />}
          </HeaderButton>

          {/* Collapsed-mode logout (desktop only — the drawer has its own) */}
          {collapsed && (
            <button onClick={onLogout}
              style={{ background: "transparent", border: "1px solid var(--border)", borderRadius: "8px", padding: "6px 10px", cursor: "pointer", color: "var(--muted)", display: "flex", alignItems: "center", gap: "6px", fontSize: "13px", fontWeight: 600 }}
              onMouseEnter={e => { e.currentTarget.style.color = "var(--alert)"; e.currentTarget.style.borderColor = "var(--alert)"; }}
              onMouseLeave={e => { e.currentTarget.style.color = "var(--muted)"; e.currentTarget.style.borderColor = "var(--border)"; }}
            >
              <LogOut size={14} /> Log out
            </button>
          )}
        </header>

        {/* Panel Content */}
        <main className="cp-fade-in" key={activeTab}
          style={{ flex: 1, padding: isMobile ? "20px 16px 32px" : "28px 32px", overflowX: "hidden" }}
        >
          {children}
        </main>
      </div>
    </div>
  );
}

function HeaderButton({ label, onClick, children }) {
  return (
    <button
      onClick={onClick}
      title={label}
      aria-label={label}
      style={{
        width: "38px", height: "38px", borderRadius: "12px", flexShrink: 0,
        background: "var(--bg)", border: "1px solid var(--border)", color: "var(--ink)",
        display: "inline-flex", alignItems: "center", justifyContent: "center",
        cursor: "pointer", transition: "background 0.15s ease, border-color 0.15s ease",
      }}
    >
      {children}
    </button>
  );
}
