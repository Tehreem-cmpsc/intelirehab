import React, { useState } from "react";
import { Lock, Loader2, ArrowRight, CheckCircle2 } from "lucide-react";
import Logo from "../components/Logo";

const passwordPattern = /^(?=.{8,}$).+$/;

export default function SetPasswordPage({ onSetPassword }) {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    if (!passwordPattern.test(password)) {
      setError("Password must be at least 8 characters.");
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
      setDone(true);
    } catch (err) {
      setError(err.message || "Unable to set password.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="cp-root min-h-screen flex items-center justify-center p-6">
      <div className="w-full max-w-sm cp-fade-in">
        <div className="flex justify-center mb-8">
          <Logo size={32} light={false} showText={true} />
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
              Choose a password for your account. Only you will know it.
            </p>

            <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">New password</label>
            <div className="relative mb-4">
              <Lock size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[14px]"
                placeholder="At least 8 characters"
                autoFocus
              />
            </div>

            <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">Confirm password</label>
            <div className="relative mb-2">
              <Lock size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
              <input
                type="password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[14px]"
                placeholder="Re-enter password"
              />
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
