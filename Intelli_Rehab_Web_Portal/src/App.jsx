import React, { useState, useEffect } from "react";
import { Moon, Sun } from "lucide-react";
import useAuth from "./domain/admin/useAuth";
import LandingPage from "./presentation/admin/pages/LandingPage";
import LoginPage from "./presentation/admin/pages/LoginPage";
import SetPasswordPage from "./presentation/admin/pages/SetPasswordPage";
import PortalShell from "./presentation/admin/pages/PortalShell";
import OverviewPanel from "./presentation/admin/panels/OverviewPanel";
import PhysiotherapistsPanel from "./presentation/admin/panels/PhysiotherapistsPanel";
import ClinicProfilePanel from "./presentation/admin/panels/ClinicProfilePanel";

// Physio components
import Sidebar from "./presentation/physio/layouts/Sidebar";
import {
  DashboardPage,
  PatientsPage,
  ApprovalsPage,
  AtRiskPage,
  ExercisesPage,
} from "./presentation/physio/pages";
import PatientUseCases from "./domain/physio/usecases/PatientUseCases";
import { THEME, setPhysioThemeMode } from "./infrastructure/physio/constants";

export default function App() {
  const [route, setRoute] = useState("landing");
  const [activeTab, setActiveTab] = useState("overview");

  // Physio states
  const [physioPage, setPhysioPage] = useState("dashboard");
  const [patients, setPatients] = useState([]);
  const [selectedPatientId, setSelectedPatientId] = useState(null);

  // One shared theme toggle for the whole app — admin and physio shells
  // used to keep separate dark-mode state that reset on every login/route
  // change. Persisted so it's the same on the next visit too.
  const [darkMode, setDarkMode] = useState(() => {
    try {
      return localStorage.getItem("theme") === "dark";
    } catch {
      return false;
    }
  });

  const auth = useAuth();

  // Deliberately NOT in a useEffect: an effect runs after React commits
  // the render, so the very render that's reacting to a new darkMode value
  // would still read THEME's old colors / the old data-theme attribute —
  // the toggle would visually do nothing until some later, unrelated
  // re-render happened to run after the effect. Doing it synchronously
  // here, before returning JSX, means every child in this same render
  // pass (ExercisesPage, Card, etc. — anything reading THEME.* or
  // document.documentElement's data-theme) sees the new theme immediately.
  // Both calls are cheap and idempotent, safe to run on every render.
  setPhysioThemeMode(darkMode);
  if (typeof document !== "undefined") {
    document.documentElement.setAttribute("data-theme", darkMode ? "dark" : "light");
  }

  // Persisting to localStorage is a genuine side effect (and doesn't
  // affect what gets rendered), so that part stays in an effect.
  useEffect(() => {
    try {
      localStorage.setItem("theme", darkMode ? "dark" : "light");
    } catch {
      // localStorage can throw in private-browsing/blocked-storage contexts —
      // theme just won't persist across reloads, not worth surfacing to the user.
    }
  }, [darkMode]);

  // Fix: load patients properly on mount
  useEffect(() => {
    let mounted = true;
    PatientUseCases.getAllPatients().then((data) => {
      if (mounted) setPatients(data || []);
    });
    return () => {
      mounted = false;
    };
  }, []);

  // Fix: auto-redirect when session restores on refresh
  useEffect(() => {
    if (!auth.loading && auth.isAuthenticated && route === "landing") {
      setRoute("app");
    }
  }, [auth.loading, auth.isAuthenticated, route]);

  const handleLogin = async (emailOrId, password, role) => {
    // Errors propagate to LoginPage's own try/catch, which shows them —
    // nothing extra needed here.
    await auth.login(emailOrId, password, role);
    setRoute("app"); // only runs on success
  };

  const handleLogout = () => {
    auth.logout();
    setRoute("landing");
    setActiveTab("overview");
    setPhysioPage("dashboard");
    setSelectedPatientId(null);
  };

  // Takes priority over everything else — a user who just clicked their
  // "set your password" email link must land here regardless of the
  // current route (landing/login/app), including on a fresh browser tab.
  if (auth.recoveryMode) {
    return <SetPasswordPage onSetPassword={auth.setNewPassword} dark={darkMode} setDark={setDarkMode} />;
  }

  // Show nothing while auth initializes (prevents flash of wrong shell)
  if (auth.loading && route === "landing") {
    return (
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "100vh" }}>
        <div>Loading…</div>
      </div>
    );
  }

  if (route === "landing") {
    return <LandingPage onGoLogin={() => setRoute("login")} dark={darkMode} setDark={setDarkMode} />;
  }

  if (route === "login") {
    return (
      <LoginPage
        onBack={() => setRoute("landing")}
        onLogin={handleLogin}
        onForgotPassword={auth.requestPasswordReset}
        loading={auth.loading}
        dark={darkMode}
        setDark={setDarkMode}
      />
    );
  }

  // Role-based shells
  if (auth.user?.authRole === "physio") {
    // Admin-set passwords are visible to the admin who created them (see
    // usePhysiotherapists.js) — force a self-chosen replacement before
    // this physio can reach anything else.
    if (auth.user.must_reset_password) {
      return (
        <SetPasswordPage
          onSetPassword={auth.completeFirstLoginReset}
          mode="firstLogin"
          dark={darkMode}
          setDark={setDarkMode}
        />
      );
    }

    const PHYSIO_TITLES = {
      dashboard: "Dashboard",
      patients: "Patients",
      approvals: "Approvals",
      atrisk: "At Risk",
      exercises: "Exercise database",
    };
    return (
      <div
        className="cp-root"
        style={{
          display: "flex",
          height: "100vh",
          fontFamily: "'Inter','Segoe UI',sans-serif",
          background: darkMode ? "#0f1f22" : THEME.slate50,
          color: darkMode ? "rgba(255,255,255,0.9)" : THEME.slate800,
          overflow: "hidden",
        }}
        data-theme={darkMode ? "dark" : "light"}
      >
        <Sidebar
          page={physioPage}
          setPage={setPhysioPage}
          onLogout={handleLogout}
          user={auth.user}
          clinic={auth.clinic}
          patients={patients}
        />
        <div
          style={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            minWidth: 0,
            background: darkMode ? "#0f1f22" : THEME.slate50,
          }}
        >
          <header
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "18px 24px",
              borderBottom: darkMode ? "1px solid rgba(255,255,255,0.08)" : `1px solid ${THEME.slate200}`,
              background: darkMode ? "#122b30" : THEME.white,
              boxShadow: darkMode ? "none" : "0 1px 0 rgba(13,110,118,0.04)",
            }}
          >
            <div>
              <div style={{ fontSize: 16, fontWeight: 800, color: darkMode ? "#F7FCFB" : THEME.slate800 }}>
                {PHYSIO_TITLES[physioPage] || "Physio Portal"}
              </div>
              <div style={{ fontSize: 12, color: darkMode ? "rgba(255,255,255,0.78)" : THEME.slate500, marginTop: 2 }}>
                {new Date().toLocaleDateString("en-PK", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}
              </div>
            </div>
            <button
              onClick={() => setDarkMode((prev) => !prev)}
              title={darkMode ? "Switch to light mode" : "Switch to dark mode"}
              style={{
                width: 38,
                height: 38,
                borderRadius: 12,
                border: darkMode ? "1px solid rgba(255,255,255,0.12)" : `1px solid ${THEME.slate200}`,
                background: darkMode ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.04)",
                color: darkMode ? "#F5F5F5" : THEME.slate700,
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                cursor: "pointer",
              }}
              aria-label={darkMode ? "Switch to light mode" : "Switch to dark mode"}
            >
              {darkMode ? <Sun size={18} /> : <Moon size={18} />}
            </button>
          </header>
          <main style={{ flex: 1, overflowY: "auto", background: darkMode ? "#0f1f22" : THEME.slate50 }}>
            {physioPage === "dashboard" && (
              <DashboardPage
                patients={patients}
                setPage={setPhysioPage}
                setSelectedPatientId={setSelectedPatientId}
              />
            )}
            {physioPage === "patients" && (
              <PatientsPage
                patients={patients}
                setPatients={setPatients}
                selectedId={selectedPatientId}
                setSelectedId={setSelectedPatientId}
              />
            )}
            {physioPage === "approvals" && (
              <ApprovalsPage patients={patients} setPatients={setPatients} />
            )}
            {physioPage === "atrisk" && <AtRiskPage patients={patients} setPatients={setPatients} />}
            {physioPage === "exercises" && <ExercisesPage />}
          </main>
        </div>
      </div>
    );
  }

  // Default to Admin shell
  return (
    <PortalShell
      user={auth.user}
      clinic={auth.clinic}
      activeTab={activeTab}
      setActiveTab={setActiveTab}
      onLogout={handleLogout}
      dark={darkMode}
      setDark={setDarkMode}
    >
      {activeTab === "overview" && <OverviewPanel user={auth.user} clinic={auth.clinic} />}
      {activeTab === "physios" && <PhysiotherapistsPanel clinic={auth.clinic} />}
      {activeTab === "profile" && <ClinicProfilePanel clinic={auth.clinic} />}
    </PortalShell>
  );
}