import React, { useState, useEffect } from "react";
import useAuth from "./domain/admin/useAuth";
import LandingPage from "./presentation/admin/pages/LandingPage";
import LoginPage from "./presentation/admin/pages/LoginPage";
import SetPasswordPage from "./presentation/admin/pages/SetPasswordPage";
import PortalShell from "./presentation/admin/pages/PortalShell";
import OverviewPanel from "./presentation/admin/panels/OverviewPanel";
import PhysiotherapistsPanel from "./presentation/admin/panels/PhysiotherapistsPanel";
import ClinicProfilePanel from "./presentation/admin/panels/ClinicProfilePanel";

// Physio components
import PhysioShell from "./presentation/physio/layouts/PhysioShell";
import {
  DashboardPage,
  PatientsPage,
  ApprovalsPage,
  AtRiskPage,
  ExercisesPage,
} from "./presentation/physio/pages";
import PatientUseCases from "./domain/physio/usecases/PatientUseCases";
import { setPhysioThemeMode } from "./infrastructure/physio/constants";

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
      <div
        className="cp-root"
        style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "100dvh" }}
      >
        <div style={{ color: "var(--muted)" }}>Loading…</div>
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

    return (
      <PhysioShell
        page={physioPage}
        setPage={setPhysioPage}
        onLogout={handleLogout}
        user={auth.user}
        clinic={auth.clinic}
        patients={patients}
        darkMode={darkMode}
        setDarkMode={setDarkMode}
      >
        {physioPage === "dashboard" && (
          <DashboardPage
            patients={patients}
            setPage={setPhysioPage}
            setSelectedPatientId={setSelectedPatientId}
            user={auth.user}
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
        {physioPage === "approvals" && <ApprovalsPage patients={patients} setPatients={setPatients} />}
        {physioPage === "atrisk" && <AtRiskPage patients={patients} setPatients={setPatients} />}
        {physioPage === "exercises" && <ExercisesPage />}
      </PhysioShell>
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