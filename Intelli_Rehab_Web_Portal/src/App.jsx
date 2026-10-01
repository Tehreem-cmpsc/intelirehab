import React, { lazy, Suspense, useState, useEffect, useCallback, useMemo, useRef } from "react";
import useAuth from "./domain/admin/useAuth";
import PatientUseCases from "./domain/physio/usecases/PatientUseCases";
import WearablePresenceUseCases from "./domain/physio/usecases/WearablePresenceUseCases";
import { setPhysioThemeMode } from "./infrastructure/physio/constants";
import useHashRoute, { navigate } from "./presentation/useHashRoute";
import ErrorNotice from "./presentation/ErrorNotice";

// Each shell/page is its own chunk, so a physio never downloads the admin
// portal (and vice versa) and the charting library only loads with the
// pages that draw charts.
const LandingPage = lazy(() => import("./presentation/admin/pages/LandingPage"));
const LoginPage = lazy(() => import("./presentation/admin/pages/LoginPage"));
const SetPasswordPage = lazy(() => import("./presentation/admin/pages/SetPasswordPage"));
const PortalShell = lazy(() => import("./presentation/admin/pages/PortalShell"));
const OverviewPanel = lazy(() => import("./presentation/admin/panels/OverviewPanel"));
const PhysiotherapistsPanel = lazy(() => import("./presentation/admin/panels/PhysiotherapistsPanel"));
const ClinicProfilePanel = lazy(() => import("./presentation/admin/panels/ClinicProfilePanel"));
const PhysioShell = lazy(() => import("./presentation/physio/layouts/PhysioShell"));
const DashboardPage = lazy(() => import("./presentation/physio/pages/DashboardPage"));
const PatientsPage = lazy(() => import("./presentation/physio/pages/PatientsPage"));
const ApprovalsPage = lazy(() => import("./presentation/physio/pages/ApprovalsPage"));
const AtRiskPage = lazy(() => import("./presentation/physio/pages/AtRiskPage"));
const ExercisesPage = lazy(() => import("./presentation/physio/pages/ExercisesPage"));

const PHYSIO_PAGES = ["dashboard", "patients", "approvals", "atrisk", "exercises"];
const ADMIN_TABS = ["overview", "physios", "profile"];
const REFRESH_MS = 60000;
const PRESENCE_REFRESH_MS = 15000; // also how fast a silently-dead band expires on screen

function FullScreenLoading() {
  return (
    <div className="cp-root" style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "100dvh" }}>
      <div style={{ color: "var(--muted)" }}>Loading…</div>
    </div>
  );
}

function AppRoutes() {
  // Location lives in the URL hash (#/login, #/app/patients/<id>), so Back,
  // Forward, refresh and deep links all work.
  const segments = useHashRoute();
  const route = segments[0] === "login" ? "login" : segments[0] === "app" ? "app" : "landing";
  const activeTab = ADMIN_TABS.includes(segments[1]) ? segments[1] : "overview";
  const physioPage = PHYSIO_PAGES.includes(segments[1]) ? segments[1] : "dashboard";
  const selectedPatientId = physioPage === "patients" ? segments[2] ?? null : null;

  const setActiveTab = useCallback((tab) => navigate(`/app/${tab}`), []);
  const setPhysioPage = useCallback((page) => navigate(`/app/${page}`), []);
  const setSelectedPatientId = useCallback(
    (id) => navigate(id ? `/app/patients/${encodeURIComponent(id)}` : "/app/patients"),
    []
  );

  // Physio states
  const [patients, setPatients] = useState([]);
  const [patientsError, setPatientsError] = useState(null);
  const reloadPatients = useRef(() => {});
  const [presence, setPresence] = useState(() => new Map());

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

  // Patients are RLS-scoped to the signed-in physio's clinic, so load them
  // once that physio is known (not on mount, when there may be no session
  // yet), and keep re-fetching so patients who sign up in the mobile app
  // show up without a page refresh.
  const physioUserId = auth.user?.authRole === "physio" ? auth.user.id : null;
  useEffect(() => {
    if (!physioUserId) {
      setPatients([]);
      setPatientsError(null);
      return;
    }
    let mounted = true;
    let inFlight = false;
    const load = async () => {
      if (inFlight) return; // never stack requests on a slow connection
      inFlight = true;
      try {
        const data = await PatientUseCases.getAllPatients();
        if (!mounted) return;
        setPatients(data || []);
        setPatientsError(null);
      } catch {
        // Keep the last list on screen, but tell the physio it may be stale.
        if (mounted) setPatientsError("Couldn't refresh patient data. What you see may be out of date.");
      } finally {
        inFlight = false;
      }
    };
    reloadPatients.current = load;

    load();
    const interval = setInterval(() => {
      if (document.visibilityState === "visible") load();
    }, REFRESH_MS);
    const onVisible = () => {
      if (document.visibilityState === "visible") load();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      mounted = false;
      clearInterval(interval);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [physioUserId]);

  // Live wearable connectivity: refreshed instantly on realtime changes, and
  // every 15 s regardless (that's what expires a band that just went quiet).
  useEffect(() => {
    if (!physioUserId) {
      setPresence(new Map());
      return;
    }
    let mounted = true;
    const load = async () => {
      try {
        const next = await WearablePresenceUseCases.getPresence();
        if (mounted) setPresence(next);
      } catch {
        // Presence is best-effort: on failure, don't claim anything is live.
        if (mounted) setPresence(new Map());
      }
    };
    load();
    const interval = setInterval(() => {
      if (document.visibilityState === "visible") load();
    }, PRESENCE_REFRESH_MS);
    const unsubscribe = WearablePresenceUseCases.subscribe(load);
    const onVisible = () => {
      if (document.visibilityState === "visible") load();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      mounted = false;
      clearInterval(interval);
      unsubscribe();
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [physioUserId]);

  // The patient list with live connectivity merged in. Pages that edit the
  // list still edit `patients` itself; this is just the display copy.
  const patientsLive = useMemo(
    () =>
      patients.map((p) => {
        const live = presence.get(p.id);
        return p.with({ wearableLive: live?.live ?? false, wearableLastSeen: live?.lastSeenAt ?? null });
      }),
    [patients, presence]
  );

  // A restored session lands on the app; the app without a session lands on login.
  useEffect(() => {
    if (auth.loading) return;
    if (auth.isAuthenticated && route === "landing") navigate("/app", { replace: true });
    if (!auth.isAuthenticated && route === "app") navigate("/login", { replace: true });
  }, [auth.loading, auth.isAuthenticated, route]);

  const handleLogin = async (emailOrId, password, role) => {
    // Errors propagate to LoginPage's own try/catch, which shows them —
    // nothing extra needed here.
    await auth.login(emailOrId, password, role);
    navigate("/app"); // only runs on success
  };

  const handleLogout = () => {
    auth.logout();
    navigate("/");
  };

  // Takes priority over everything else — a user who just clicked their
  // "set your password" email link must land here regardless of the
  // current route (landing/login/app), including on a fresh browser tab.
  if (auth.recoveryMode) {
    return <SetPasswordPage onSetPassword={auth.setNewPassword} dark={darkMode} setDark={setDarkMode} />;
  }

  // Show nothing while auth initializes (prevents flash of wrong shell)
  if (route === "app" && !auth.user) return <FullScreenLoading />;
  if (auth.loading && route === "landing") return <FullScreenLoading />;

  if (route === "landing") {
    return <LandingPage onGoLogin={() => navigate("/login")} dark={darkMode} setDark={setDarkMode} />;
  }

  if (route === "login") {
    return (
      <LoginPage
        onBack={() => navigate("/")}
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
        patients={patientsLive}
        darkMode={darkMode}
        setDarkMode={setDarkMode}
      >
        <ErrorNotice message={patientsError} onRetry={() => reloadPatients.current()} />
        {physioPage === "dashboard" && (
          <DashboardPage
            patients={patientsLive}
            setPage={setPhysioPage}
            setSelectedPatientId={setSelectedPatientId}
            user={auth.user}
          />
        )}
        {physioPage === "patients" && (
          <PatientsPage
            patients={patientsLive}
            selectedId={selectedPatientId}
            setSelectedId={setSelectedPatientId}
            currentPhysioId={auth.user.physio_id}
          />
        )}
        {physioPage === "approvals" && (
          <ApprovalsPage patients={patientsLive} setPatients={setPatients} currentPhysioId={auth.user.physio_id} />
        )}
        {physioPage === "atrisk" && <AtRiskPage patients={patientsLive} setPatients={setPatients} />}
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
      {activeTab === "profile" && <ClinicProfilePanel clinic={auth.clinic} onClinicUpdated={auth.updateClinic} />}
    </PortalShell>
  );
}

export default function App() {
  return (
    <Suspense fallback={<FullScreenLoading />}>
      <AppRoutes />
    </Suspense>
  );
}
