import React, { useState } from "react";
import { Lock, Loader2, ArrowRight, CheckCircle2, Eye, EyeOff } from "lucide-react";
import Logo from "../components/Logo";
import ThemeToggle from "../components/ThemeToggle";
import { passwordError } from "../../../infrastructure/validation/password";

export default function SetPasswordPage({ onSetPassword, mode = "recovery", dark, setDark }) {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    const pwError = passwordError(password);
    if (pwError) {
      setError(pwError);
      return;
    }
    if (password !== confirm) {
      setError("Passwords don't match.");
      return;
    }
    setError("");
    setSubmitting(true);
    try {
      await onSetPassword(password);
      // In "firstLogin" mode the caller flips must_reset_password to
      // false as part of onSetPassword, which makes the parent stop
      // rendering this page and swap straight into the portal — no
      // separate "done" screen needed, it would just flash and vanish.
      if (mode === "recovery") setDone(true);
    } catch (err) {
      setError(err.message || "Unable to set password.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="cp-root min-h-screen flex items-center justify-center p-6 relative">
      {setDark && (
        <div className="absolute top-6 right-6">
          <ThemeToggle dark={dark} setDark={setDark} />
        </div>
      )}
      <div className="w-full max-w-sm cp-fade-in">
        <div className="flex justify-center mb-8">
          <Logo size={32} light showText={true} />
        </div>

        {done ? (
          <div className="text-center">
            <CheckCircle2 size={40} className="text-[var(--success)] mx-auto mb-3" />
            <h1 className="cp-display font-bold text-[22px] mb-1.5 text-[var(--ink)]">Password set</h1>
            <p className="text-[14px] text-[var(--muted)]">
              You can now log in with your new password. If your account is still pending approval,
              your clinic administrator needs to approve it first.
            </p>
          </div>
        ) : (
          <form onSubmit={submit}>
            <h1 className="cp-display font-bold text-[22px] mb-1.5 text-[var(--ink)]">Set your password</h1>
            <p className="text-[14px] text-[var(--muted)] mb-6">
              {mode === "firstLogin"
                ? "Your clinic administrator set a temporary password to get you started — choose your own now before continuing."
                : "Choose a password for your account. Only you will know it."}
            </p>

            <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">New password</label>
            <div className="relative mb-4">
              <Lock size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="cp-input cp-focus w-full rounded-lg pl-9 pr-10 py-2.5 text-[14px]"
                placeholder="At least 8 characters"
                autoFocus
              />
              <button
                type="button"
                onClick={() => setShowPassword((v) => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--muted)] bg-transparent border-none cursor-pointer p-0 flex"
                aria-label={showPassword ? "Hide password" : "Show password"}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>

            <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">Confirm password</label>
            <div className="relative mb-2">
              <Lock size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
              <input
                type={showConfirm ? "text" : "password"}
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                className="cp-input cp-focus w-full rounded-lg pl-9 pr-10 py-2.5 text-[14px]"
                placeholder="Re-enter password"
              />
              <button
                type="button"
                onClick={() => setShowConfirm((v) => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--muted)] bg-transparent border-none cursor-pointer p-0 flex"
                aria-label={showConfirm ? "Hide password" : "Show password"}
              >
                {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>

            {error && <div className="text-[13px] text-[var(--alert)] mb-4 mt-2">{error}</div>}

            <button
              type="submit"
              disabled={submitting}
              className="cp-btn-primary cp-focus w-full rounded-lg py-3 text-[14px] flex items-center justify-center gap-2 cursor-pointer border-none mt-2"
            >
              {submitting ? (
                <>
                  <Loader2 size={16} className="animate-spin" /> Saving…
                </>
              ) : (
                <>
                  Set password <ArrowRight size={15} />
                </>
              )}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
