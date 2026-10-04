import { useState, useEffect, useCallback, useRef } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

// Wrong credentials and "the sign-in service isn't reachable" must not look
// the same: the first is the user's to fix, the second is a deployment problem
// (function not deployed, CORS origin not allowed, offline) that would
// otherwise be invisible behind "Invalid ID or password".
async function physioSignInError(error) {
  const status = error?.context?.status;
  if (status === 401) return new Error("Invalid ID or password.");
  if (status === 429) return new Error("Too many attempts. Try again in a few minutes.");
  console.error("physio-auth sign-in failed:", error);
  return new Error(
    "Physiotherapist sign-in is unavailable right now. Check your connection, or contact your administrator if it persists."
  );
}

export default function useAuth() {
  const [user, setUser] = useState(null);
  const [clinic, setClinic] = useState(null);
  const [loading, setLoading] = useState(true);
  // True while the browser is in a Supabase password-recovery session (i.e.
  // the user just clicked a "set your password" email link). Must be
  // checked BEFORE the pending-approval gate below — otherwise a Pending
  // physio clicking their invite link would get signed straight back out
  // before they ever got a chance to set a password.
  const [recoveryMode, setRecoveryMode] = useState(false);
  // supabase-js re-fires SIGNED_IN on tab refocus and token refresh. These
  // let the listener ignore those (same user already loaded) and ignore the
  // SIGNED_IN that login() itself triggers, which login() handles directly.
  const knownUserId = useRef(null);
  const loginInFlight = useRef(false);

  const resolveUser = useCallback(async (authUser) => {
    if (!authUser) return { user: null, clinic: null };

    // 1. Try physiotherapist
    const { data: physios, error: pErr } = await supabase
      .from("physiotherapists")
      .select("*, clinics(*)")
      .eq("user_id", authUser.id)
      .limit(1);

    if (pErr) console.error("Physio fetch error:", pErr);

    const physio = physios?.[0];
    if (physio) {
      return {
        user: {
          id: authUser.id,
          email: authUser.email,
          authRole: "physio",
          name: physio.full_name || authUser.user_metadata?.full_name || authUser.email,
          physio_id: physio.id,
          physio_code: physio.physio_code,
          specialization: physio.specialization,
          license_number: physio.license_number,
          status: physio.status,
          must_reset_password: physio.must_reset_password,
        },
        clinic: physio.clinics,
      };
    }

    // 2. Try clinic admin
    const { data: clinics, error: cErr } = await supabase
      .from("clinics")
      .select("*")
      .eq("admin_user_id", authUser.id)
      .limit(1);

    if (cErr) console.error("Clinic fetch error:", cErr);

    const clinic = clinics?.[0];
    if (clinic) {
      const fullName = authUser.user_metadata?.full_name?.trim() || null;
      return {
        user: {
          id: authUser.id,
          email: authUser.email,
          authRole: "admin",
          // hasName: false means `name` is only the email, which is not a name to greet someone by.
          name: fullName || authUser.email,
          hasName: Boolean(fullName),
          clinic_id: clinic.id,
        },
        clinic,
      };
    }

    return { user: null, clinic: null };
  }, []);

  // A physiotherapist whose credentials haven't been approved yet by their
  // clinic admin. Applies both at login and when an existing session is
  // restored (e.g. on page refresh) — approval status can change at any time.
  const isUnapprovedPhysio = (user) => user?.authRole === "physio" && user.status !== "Active";

  useEffect(() => {
    let mounted = true;

    const init = async () => {
      const { data: { session } } = await supabase.auth.getSession();

      if (session?.user && mounted) {
        const result = await resolveUser(session.user);
        if (isUnapprovedPhysio(result.user)) {
          await supabase.auth.signOut();
          setUser(null);
          setClinic(null);
        } else {
          knownUserId.current = result.user?.id ?? null;
          setUser(result.user);
          setClinic(result.clinic);
        }
      }
      if (mounted) setLoading(false);
    };

    init();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        if (event === "PASSWORD_RECOVERY") {
          // Skip the normal resolve/approval flow entirely while they're
          // setting their password.
          if (mounted) setRecoveryMode(true);
          return;
        }
        if (event === "SIGNED_IN" && session?.user) {
          if (loginInFlight.current || knownUserId.current === session.user.id) return;
          // Not awaited here: supabase-js runs this callback while it is still processing the
          // auth change, so calling back into supabase (resolveUser queries, signOut) from inside
          // it can deadlock. Deferring one tick lets it finish first.
          setTimeout(async () => {
            const result = await resolveUser(session.user);
            if (!mounted) return;
            if (isUnapprovedPhysio(result.user)) {
              await supabase.auth.signOut();
              setUser(null);
              setClinic(null);
            } else {
              knownUserId.current = result.user?.id ?? null;
              setUser(result.user);
              setClinic(result.clinic);
            }
          }, 0);
        } else if (event === "SIGNED_OUT") {
          knownUserId.current = null;
          if (mounted) {
            setUser(null);
            setClinic(null);
            setRecoveryMode(false);
          }
        }
      }
    );

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [resolveUser]);

  const login = useCallback(
    async (emailOrId, password, role) => {
      setLoading(true);
      loginInFlight.current = true;
      try {
        const email = emailOrId;

        let authUser;
        if (role === "physio") {
          // The ID -> email lookup and the password check happen server-side
          // (physio-auth), so the browser never learns a physio's email and
          // a wrong ID looks identical to a wrong password.
          const { data, error } = await supabase.functions.invoke("physio-auth", {
            body: { action: "sign-in", physioCode: emailOrId.trim(), password },
          });
          if (error?.context?.status === 404 && import.meta.env.DEV) {
            // DEVELOPMENT ONLY (removed from production builds): the Edge
            // Function isn't deployed yet, so use the old direct lookup so
            // local work isn't blocked. Needs get_physio_email to still be
            // executable, i.e. supabase_security_hardening.sql not yet run.
            console.warn("physio-auth is not deployed - using the dev-only fallback sign-in.");
            const { data: lookupEmail, error: rpcErr } = await supabase.rpc("get_physio_email", {
              physio_code: emailOrId.trim(),
            });
            if (rpcErr || !lookupEmail) throw new Error("Invalid ID or password.");
            const { data: pw, error: pwErr } = await supabase.auth.signInWithPassword({
              email: lookupEmail,
              password,
            });
            if (pwErr) throw new Error("Invalid ID or password.");
            authUser = pw.user;
          } else {
            if (error || !data?.session) throw await physioSignInError(error);
            const { data: sessionData, error: sessionErr } = await supabase.auth.setSession(data.session);
            if (sessionErr || !sessionData.user) throw new Error("Invalid ID or password.");
            authUser = sessionData.user;
          }
        } else {
          const { data, error } = await supabase.auth.signInWithPassword({ email, password });
          if (error) throw error;
          authUser = data.user;
        }

        const result = await resolveUser(authUser);

        // Role mismatch guard
        if (role && result.user?.authRole !== role) {
          await supabase.auth.signOut();
          throw new Error(`Access denied. This account is not a ${role}.`);
        }

        // Pending physios have correct credentials but haven't been
        // approved by their clinic admin yet.
        if (isUnapprovedPhysio(result.user)) {
          await supabase.auth.signOut();
          throw new Error(
            result.user.status === "Rejected"
              ? "Your account has been rejected. Contact your clinic administrator."
              : "Your account is pending approval by your clinic administrator."
          );
        }

        knownUserId.current = result.user?.id ?? null;
        setUser(result.user);
        setClinic(result.clinic);
      } finally {
        loginInFlight.current = false;
        setLoading(false);
      }
    },
    [resolveUser]
  );

  const requestPasswordReset = useCallback(async (idOrEmail, role) => {
    const email = idOrEmail.trim();

    if (role === "physio") {
      // Always resolves the same way, whether or not the ID exists.
      const { error } = await supabase.functions.invoke("physio-auth", {
        body: { action: "reset", physioCode: email },
      });
      if (error) throw new Error("Unable to send password reset email.");
      return;
    }

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: window.location.origin,
    });
    if (error) throw new Error(error.message || "Unable to send password reset email.");
  }, []);

  // The admin's own name lives in their Supabase login (user_metadata.full_name): the clinics
  // table holds the clinic's details, not a person's.
  const updateAdminName = useCallback(async (fullName) => {
    const name = fullName.trim();
    const { error } = await supabase.auth.updateUser({ data: { full_name: name } });
    if (error) throw new Error(error.message || "Unable to save your name.");
    setUser((prev) => (prev ? { ...prev, name: name || prev.email, hasName: Boolean(name) } : prev));
  }, []);

  const logout = useCallback(async () => {
    knownUserId.current = null;
    setLoading(true);
    await supabase.auth.signOut();
    setUser(null);
    setClinic(null);
    setLoading(false);
  }, []);

  // Called from the "set your password" page after a recovery-email click.
  // Signs them out afterward — they still need admin approval (if pending),
  // so this should never drop them straight into the portal.
  const setNewPassword = useCallback(async (password) => {
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw new Error(error.message || "Unable to set password.");
    await supabase.auth.signOut();
    setRecoveryMode(false);
  }, []);

  // Called from the first-login "set your password" gate (App.jsx checks
  // user.must_reset_password) — the physio is already in a normal signed-in
  // session at this point, not a recovery flow, so unlike setNewPassword
  // above this does NOT sign them out; they should land straight in the
  // portal once it resolves.
  const completeFirstLoginReset = useCallback(async (password) => {
    const { error } = await supabase.auth.updateUser({ password });
    if (error) throw new Error(error.message || "Unable to set password.");

    // A narrow RPC (physios can't update their own row directly).
    const { error: updateErr } = await supabase.rpc("complete_first_login_reset");
    if (updateErr) throw new Error(updateErr.message || "Unable to update your account.");

    setUser((prev) => (prev ? { ...prev, must_reset_password: false } : prev));
  }, []);

  return {
    user,
    clinic,
    loading,
    login,
    logout,
    isAuthenticated: !!user,
    recoveryMode,
    setNewPassword,
    completeFirstLoginReset,
    requestPasswordReset,
    updateClinic: setClinic,
    updateAdminName,
  };
}