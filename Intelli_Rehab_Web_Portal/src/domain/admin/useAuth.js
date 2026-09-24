import { useState, useEffect, useCallback } from "react";
import { supabase } from "../../infrastructure/supabase/supabaseClient";

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
      .eq("email", authUser.email)
      .limit(1);

    if (cErr) console.error("Clinic fetch error:", cErr);

    const clinic = clinics?.[0];
    if (clinic) {
      return {
        user: {
          id: authUser.id,
          email: authUser.email,
          authRole: "admin",
          name: authUser.user_metadata?.full_name || authUser.email,
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
          setUser(result.user);
          setClinic(result.clinic);
        }
      }
      if (mounted) setLoading(false);
    };

    init();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (event === "PASSWORD_RECOVERY") {
          // Skip the normal resolve/approval flow entirely while they're
          // setting their password.
          if (mounted) setRecoveryMode(true);
          return;
        }
        if (event === "SIGNED_IN" && session?.user) {
          const result = await resolveUser(session.user);
          if (mounted) {
            if (isUnapprovedPhysio(result.user)) {
              await supabase.auth.signOut();
              setUser(null);
              setClinic(null);
            } else {
              setUser(result.user);
              setClinic(result.clinic);
            }
          }
        } else if (event === "SIGNED_OUT") {
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
      try {
        let email = emailOrId;

        // If physio, look up email by physio code first
        if (role === "physio") {
          const { data: lookupEmail, error: rpcErr } = await supabase.rpc(
            "get_physio_email",
            { physio_code: emailOrId.trim() }
          );

          if (rpcErr || !lookupEmail) {
            throw new Error("Physio ID not found.");
          }
          email = lookupEmail;
        }

        // Sign in with Supabase Auth
        const { data, error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error) throw error;

        const result = await resolveUser(data.user);

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

        setUser(result.user);
        setClinic(result.clinic);
      } finally {
        setLoading(false);
      }
    },
    [resolveUser]
  );

  const requestPasswordReset = useCallback(async (idOrEmail, role) => {
    let email = idOrEmail.trim();

    if (role === "physio") {
      const { data: lookupEmail, error: rpcErr } = await supabase.rpc(
        "get_physio_email",
        { physio_code: email }
      );
      if (rpcErr || !lookupEmail) {
        throw new Error("Physio ID not found.");
      }
      email = lookupEmail;
    }

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: window.location.origin,
    });
    if (error) throw new Error(error.message || "Unable to send password reset email.");
  }, []);

  const logout = useCallback(async () => {
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

    if (user?.physio_id) {
      const { error: updateErr } = await supabase
        .from("physiotherapists")
        .update({ must_reset_password: false })
        .eq("id", user.physio_id);
      if (updateErr) throw new Error(updateErr.message || "Unable to update your account.");
    }

    setUser((prev) => (prev ? { ...prev, must_reset_password: false } : prev));
  }, [user]);

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
  };
}