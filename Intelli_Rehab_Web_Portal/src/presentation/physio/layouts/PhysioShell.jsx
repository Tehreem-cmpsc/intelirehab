import { useEffect, useState } from "react";
import { Menu, Moon, Sun } from "lucide-react";
import { THEME } from "../../../infrastructure/physio/constants";
import useIsMobile from "../../useIsMobile";
import Sidebar from "./Sidebar";

const TITLES = {
  dashboard: "Dashboard",
  patients: "Patients",
  approvals: "Approvals",
  atrisk: "At Risk",
  exercises: "Exercises",
};

// Physio app frame: sidebar + header + scrolling page. On narrow screens the
// sidebar becomes a slide-in drawer opened from the header's menu button.
export default function PhysioShell({
  page,
  setPage,
  onLogout,
  user,
  clinic,
  patients,
  darkMode,
  setDarkMode,
  children,
}) {
  const isMobile = useIsMobile();
  const [drawerOpen, setDrawerOpen] = useState(false);

  // Leaving mobile layout (rotating a tablet, resizing) shouldn't leave a
  // stale open drawer behind.
  useEffect(() => {
    if (!isMobile) setDrawerOpen(false);
  }, [isMobile]);

  const goTo = (next) => {
    setPage(next);
    setDrawerOpen(false);
  };

  return (
    <div
      className="cp-root"
      style={{
        display: "flex",
        height: "100dvh",
        fontFamily: "'Inter','Segoe UI',sans-serif",
        background: THEME.slate50,
        color: THEME.slate800,
        overflow: "hidden",
      }}
      data-theme={darkMode ? "dark" : "light"}
    >
      <Sidebar
        page={page}
        setPage={goTo}
        onLogout={onLogout}
        user={user}
        clinic={clinic}
        patients={patients}
        mobile={isMobile}
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
      />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
        <header
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: isMobile ? "12px 16px" : "18px 24px",
            borderBottom: `1px solid ${THEME.slate200}`,
            background: THEME.surface,
            boxShadow: darkMode ? "none" : "0 1px 0 rgba(13,110,118,0.04)",
          }}
        >
          {isMobile && (
            <IconButton label="Open menu" onClick={() => setDrawerOpen(true)}>
              <Menu size={18} />
            </IconButton>
          )}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div
              style={{
                fontSize: 16,
                fontWeight: 800,
                color: THEME.slate800,
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis",
              }}
            >
              {TITLES[page] || "Physio Portal"}
            </div>
            <div
              style={{
                fontSize: 12,
                color: THEME.slate400,
                marginTop: 2,
                whiteSpace: "nowrap",
                overflow: "hidden",
                textOverflow: "ellipsis",
              }}
            >
              {new Date().toLocaleDateString("en-PK", {
                weekday: isMobile ? "short" : "long",
                year: "numeric",
                month: isMobile ? "short" : "long",
                day: "numeric",
              })}
            </div>
          </div>
          <IconButton
            label={darkMode ? "Switch to light mode" : "Switch to dark mode"}
            onClick={() => setDarkMode((prev) => !prev)}
          >
            {darkMode ? <Sun size={18} /> : <Moon size={18} />}
          </IconButton>
        </header>
        <main style={{ flex: 1, overflowY: "auto", overflowX: "hidden", background: THEME.slate50 }}>
          {children}
        </main>
      </div>
    </div>
  );
}

function IconButton({ label, onClick, children }) {
  return (
    <button
      onClick={onClick}
      title={label}
      aria-label={label}
      style={{
        width: 38,
        height: 38,
        borderRadius: 12,
        border: `1px solid ${THEME.slate200}`,
        background: THEME.slate100,
        color: THEME.slate800,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        cursor: "pointer",
        flexShrink: 0,
      }}
    >
      {children}
    </button>
  );
}
