import React, { useState } from "react";
import { LogOut, LayoutGrid, Users, Building2, ChevronLeft, ChevronRight, Sun, Moon } from "lucide-react";
import Logo, { LogoIcon } from "../components/Logo";

const NAV_ITEMS = [
  { id: "overview",  label: "Dashboard",          icon: LayoutGrid },
  { id: "physios",   label: "Physiotherapists",   icon: Users },
  { id: "profile",   label: "Clinic Profile",     icon: Building2 },
];

export default function PortalShell({ user, clinic, activeTab, setActiveTab, onLogout, dark, setDark, children }) {
  const [collapsed, setCollapsed] = useState(false);

  const initials = user?.name?.split(" ").map((p) => p[0]).join("") ?? "A";

  // Sidebar style tokens — dark or light
  const s = {
    sidebarBg:   dark ? "#0b2428"                       : "#093D42",
    sidebarBorder: "rgba(255,255,255,0.06)",
    badgeBg:     dark ? "rgba(255,255,255,0.06)"        : "rgba(255,255,255,0.05)",
    badgeBorder: "rgba(255,255,255,0.08)",
    activeNavBg: "rgba(49, 232, 198, 0.12)",
    activeNavColor: "#31E8C6",
    mutedNavColor: "rgba(255,255,255,0.55)",
    footerBorder: "rgba(255,255,255,0.07)",
    // main area
    mainBg:      dark ? "#0f1f22" : "var(--bg)",
    headerBg:    dark ? "#122b30" : "var(--surface)",
    headerBorder: dark ? "rgba(255,255,255,0.06)" : "var(--border)",
    titleColor:  dark ? "#F7FCFB"  : "var(--ink)",
    mutedColor:  dark ? "rgba(255,255,255,0.78)"  : "var(--muted)",
  };

  return (
    <div style={{ display: "flex", minHeight: "100vh", background: s.mainBg, transition: "background 0.25s ease" }}
         data-theme={dark ? "dark" : "light"}
         className="cp-root">

      {/* ── Sidebar ── */}
      <aside style={{
        width: collapsed ? "72px" : "240px",
        minHeight: "100vh",
        background: s.sidebarBg,
        borderRight: `1px solid ${s.sidebarBorder}`,
        transition: "width 0.25s cubic-bezier(.4,0,.2,1), background 0.25s ease",
        display: "flex", flexDirection: "column", flexShrink: 0,
        position: "sticky", top: 0, overflow: "hidden",
      }}>

        {/* Sidebar Header */}
        <div style={{
          padding: collapsed ? "20px 0" : "20px 20px",
          display: "flex", alignItems: "center",
          justifyContent: collapsed ? "center" : "space-between",
          borderBottom: `1px solid ${s.sidebarBorder}`,
          minHeight: "72px", gap: "8px",
        }}>
          {collapsed ? <LogoIcon size={32} light /> : <Logo size={30} light showText />}
          <button
            onClick={() => setCollapsed(!collapsed)}
            style={{
              background: "rgba(255,255,255,0.08)", border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: "8px", color: "rgba(255,255,255,0.7)",
              width: "28px", height: "28px", display: "flex", alignItems: "center",
              justifyContent: "center", cursor: "pointer", flexShrink: 0, transition: "background 0.15s",
            }}
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            onMouseEnter={e => e.currentTarget.style.background = "rgba(255,255,255,0.15)"}
            onMouseLeave={e => e.currentTarget.style.background = "rgba(255,255,255,0.08)"}
          >
            {collapsed ? <ChevronRight size={14} /> : <ChevronLeft size={14} />}
          </button>
        </div>

        {/* Clinic Badge */}
        {!collapsed && (
          <div style={{
            margin: "14px 16px", padding: "8px 12px",
            background: s.badgeBg, border: `1px solid ${s.badgeBorder}`, borderRadius: "10px",
          }}>
            <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.4)", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.1em" }}>Active Clinic</div>
            <div style={{ fontSize: "12px", color: "rgba(255,255,255,0.85)", fontWeight: 600, marginTop: "2px", lineHeight: 1.3 }}>{clinic?.name ?? "—"}</div>
          </div>
        )}

        {/* Navigation */}
        <nav style={{ padding: collapsed ? "8px 8px" : "8px 10px", flex: 1, display: "flex", flexDirection: "column", gap: "3px" }}>
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const active = activeTab === item.id;
            return (
              <button key={item.id} onClick={() => setActiveTab(item.id)}
                title={collapsed ? item.label : undefined}
                style={{
                  display: "flex", alignItems: "center", gap: "11px",
                  padding: collapsed ? "10px" : "10px 12px",
                  justifyContent: collapsed ? "center" : "flex-start",
                  borderRadius: "10px", border: "none", cursor: "pointer",
                  transition: "background 0.15s, color 0.15s",
                  background: active ? s.activeNavBg : "transparent",
                  color: active ? s.activeNavColor : s.mutedNavColor,
                  fontWeight: active ? 700 : 500, fontSize: "13.5px",
                  width: "100%", textAlign: "left", whiteSpace: "nowrap",
                  outline: "none", position: "relative",
                }}
                onMouseEnter={e => { if (!active) { e.currentTarget.style.background = "rgba(255,255,255,0.06)"; e.currentTarget.style.color = "rgba(255,255,255,0.85)"; }}}
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
                <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.72)", marginTop: "1px", whiteSpace: "nowrap" }}>{user?.role}</div>
              </div>
            )}
          </div>
          {!collapsed && (
            <button onClick={onLogout} title="Log out"
              style={{
                background: "transparent", border: "1px solid rgba(255,255,255,0.1)",
                borderRadius: "8px", color: "rgba(255,255,255,0.45)",
                padding: "6px", cursor: "pointer", display: "flex",
                alignItems: "center", justifyContent: "center",
                transition: "background 0.15s, color 0.15s", flexShrink: 0,
              }}
              onMouseEnter={e => { e.currentTarget.style.background = "rgba(217,98,72,0.15)"; e.currentTarget.style.color = "#D96248"; }}
              onMouseLeave={e => { e.currentTarget.style.background = "transparent"; e.currentTarget.style.color = "rgba(255,255,255,0.45)"; }}
              aria-label="Log out"
            >
              <LogOut size={15} />
            </button>
          )}
        </div>
      </aside>

      {/* ── Main Content ── */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0, minHeight: "100vh", transition: "background 0.25s ease" }}>

        {/* Top Header Bar */}
        <header style={{
          background: s.headerBg, borderBottom: `1px solid ${s.headerBorder}`,
          padding: "14px 28px", display: "flex", alignItems: "center",
          justifyContent: "space-between", position: "sticky", top: 0, zIndex: 10,
          transition: "background 0.25s ease, border-color 0.25s ease",
        }}>
          <div>
            <div className="cp-display font-bold text-[16px]" style={{ color: s.titleColor }}>
              {NAV_ITEMS.find(t => t.id === activeTab)?.label ?? "Dashboard"}
            </div>
            <div style={{ fontSize: "12px", color: s.mutedColor, marginTop: "1px" }}>
              {new Date().toLocaleDateString("en-PK", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}
            </div>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <button
              onClick={() => setDark(!dark)}
              title={dark ? "Switch to light mode" : "Switch to dark mode"}
              style={{
                width: "38px", height: "38px", borderRadius: "12px",
                background: dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.05)",
                border: `1px solid ${dark ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.08)"}`,
                color: dark ? "#F5F5F5" : "#3D3D3D",
                display: "inline-flex", alignItems: "center", justifyContent: "center",
                cursor: "pointer", transition: "background 0.15s ease, border-color 0.15s ease",
              }}
              onMouseEnter={e => e.currentTarget.style.background = dark ? "rgba(255,255,255,0.16)" : "rgba(0,0,0,0.08)"}
              onMouseLeave={e => e.currentTarget.style.background = dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.05)"}
              aria-label={dark ? "Switch to light mode" : "Switch to dark mode"}
            >
              {dark ? <Sun size={18} /> : <Moon size={18} />}
            </button>

            {/* Collapsed-mode logout */}
            {collapsed && (
              <button onClick={onLogout}
                style={{ background: "transparent", border: `1px solid ${s.headerBorder}`, borderRadius: "8px", padding: "6px 10px", cursor: "pointer", color: s.mutedColor, display: "flex", alignItems: "center", gap: "6px", fontSize: "13px", fontWeight: 600 }}
                onMouseEnter={e => { e.currentTarget.style.color = "#D96248"; e.currentTarget.style.borderColor = "#D96248"; }}
                onMouseLeave={e => { e.currentTarget.style.color = s.mutedColor; e.currentTarget.style.borderColor = s.headerBorder; }}
              >
                <LogOut size={14} /> Log out
              </button>
            )}
          </div>
        </header>

        {/* Panel Content */}
        <main className="cp-fade-in" key={activeTab}
          style={{ flex: 1, padding: "28px 32px", overflowY: "auto" }}
        >
          {children}
        </main>
      </div>
    </div>
  );
}
