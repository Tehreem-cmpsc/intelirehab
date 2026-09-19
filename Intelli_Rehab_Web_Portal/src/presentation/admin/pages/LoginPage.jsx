import React, { useState } from "react";
import { Mail, Lock, Loader2, ArrowRight, User } from "lucide-react";
import Logo from "../components/Logo";
import RadialProgress from "../components/RadialProgress";

export default function LoginPage({ onBack, onLogin, onForgotPassword, loading }) {
  const [role, setRole] = useState("admin"); // admin | physio
  const [email, setEmail] = useState("");
  const [physioId, setPhysioId] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [info, setInfo] = useState("");
  const [resetting, setResetting] = useState(false);

  const handleRoleChange = (newRole) => {
    setRole(newRole);
    setError("");
    setInfo("");
  };

  const handleForgotPassword = async () => {
    const idOrEmail = role === "admin" ? email.trim() : physioId.trim();
    if (!idOrEmail) {
      setError(role === "admin" ? "Enter your email first." : "Enter your Physiotherapist ID first.");
      return;
    }
    setError("");
    setInfo("");
    setResetting(true);
    try {
      await onForgotPassword(idOrEmail, role);
      setInfo("If that account exists, a password-reset email is on its way.");
    } catch (err) {
      setError(err.message || "Unable to send password reset email.");
    } finally {
      setResetting(false);
    }
  };

  const submit = async (e) => {
    e.preventDefault();
    const idOrEmail = role === "admin" ? email.trim() : physioId.trim();
    if (!idOrEmail || !password.trim()) {
      setError(role === "admin" ? "Please enter both email and password." : "Please enter both physiotherapist ID and password.");
      return;
    }

    setError("");
    setInfo("");
    try {
      await onLogin(idOrEmail, password, role);
    } catch (err) {
      setError(err.message || "Unable to sign in. Please check your credentials.");
    }
  };

  return (
    <div className="cp-root min-h-screen grid grid-cols-1 md:grid-cols-2">
      <div className="hidden md:flex flex-col justify-between p-12 relative overflow-hidden" style={{ background: `linear-gradient(160deg, var(--primary-deep), var(--primary))` }}>
        <svg className="cp-arc-spin absolute -left-32 -bottom-32 opacity-15" width="480" height="480" viewBox="0 0 480 480">
          <circle cx="240" cy="240" r="210" stroke="white" strokeWidth="2" fill="none" strokeDasharray="10 14" />
        </svg>
        <button onClick={onBack} className="cp-focus flex items-center w-fit cursor-pointer bg-transparent border-none">
          <Logo size={36} light={true} showText={true} />
        </button>
        <div className="relative cp-rise">
          <RadialProgress value={70} size={110} stroke={9} color="var(--accent)" track="rgba(255,255,255,0.2)" label="70%" labelColor="#fff" />
          <p className="text-white text-[20px] leading-snug mt-8 max-w-xs cp-display font-medium">
            {role === "admin" 
              ? "\"Every physiotherapist we add shows us exactly how their patients are recovering.\""
              : "\"Inteli-Rehab translates raw kinematics into genuine clinical progress reports.\""}
          </p>
          <p className="text-white/60 text-[13px] mt-3">
            {role === "admin" ? "Clinic Administrator, partner practice" : "Physiotherapist, partner practice"}
          </p>
        </div>
        <div className="text-white/50 text-[12px]">© Inteli-Rehab — Smart Rehabilitation System</div>
      </div>

      <div className="flex items-center justify-center p-8">
        <form onSubmit={submit} className="w-full max-w-sm cp-fade-in">
          <button onClick={onBack} type="button" className="md:hidden flex items-center mb-8 cp-focus cursor-pointer bg-transparent border-none">
            <Logo size={32} light={false} showText={true} />
          </button>
          <h1 className="cp-display font-bold text-[26px] mb-1.5 text-[var(--ink)]">Welcome back</h1>
          <p className="text-[14px] text-[var(--muted)] mb-6">
            {role === "admin" ? "Log in to manage your clinic's physiotherapists." : "Log in to view patient progress and assign exercises."}
          </p>

          {/* Role Selector Toggle */}
          <div className="flex bg-[var(--primary-tint)] p-1 rounded-xl mb-6 border border-[var(--border)]">
            <button
              type="button"
              onClick={() => handleRoleChange("admin")}
              className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-none ${
                role === "admin"
                  ? "bg-[var(--primary)] text-white shadow-sm"
                  : "text-[var(--primary)] hover:bg-[var(--border)]/40"
              }`}
            >
              Clinic Admin
            </button>
            <button
              type="button"
              onClick={() => handleRoleChange("physio")}
              className={`flex-1 py-2 text-xs font-semibold rounded-lg transition-all cursor-pointer border-none ${
                role === "physio"
                  ? "bg-[var(--primary)] text-white shadow-sm"
                  : "text-[var(--primary)] hover:bg-[var(--border)]/40"
              }`}
            >
              Physiotherapist
            </button>
          </div>

          {role === "admin" ? (
            <>
              <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">Email</label>
              <div className="relative mb-4">
                <Mail size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[14px]"
                  placeholder="e.g. admin@abbottabadmedical.pk"
                />
              </div>
            </>
          ) : (
            <>
              <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">Physiotherapist ID</label>
              <div className="relative mb-4">
                <User size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
                <input
                  type="text"
                  value={physioId}
                  onChange={(e) => setPhysioId(e.target.value)}
                  className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[14px] cp-mono"
                  placeholder="e.g. DR-AHMED-001"
                  autoComplete="off"
                />
              </div>
            </>
          )}

          <label className="block text-[13px] font-semibold mb-1.5 text-[var(--ink)]">Password</label>
          <div className="relative mb-2">
            <Lock size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]" />
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="cp-input cp-focus w-full rounded-lg pl-9 pr-3 py-2.5 text-[14px]"
              placeholder="••••••••"
              autoComplete="off"
            />
          </div>
          <button
            type="button"
            onClick={handleForgotPassword}
            disabled={resetting}
            className="text-[12px] text-[var(--primary)] font-semibold mb-4 block bg-transparent border-none cursor-pointer p-0 hover:underline"
          >
            {resetting ? "Sending…" : "Forgot password?"}
          </button>

          {info && <div className="text-[13px] text-[var(--success)] mb-4">{info}</div>}
          {error && <div className="text-[13px] text-[var(--alert)] mb-4">{error}</div>}
          <button type="submit" disabled={loading} className="cp-btn-primary cp-focus w-full rounded-lg py-3 text-[14px] flex items-center justify-center gap-2 cursor-pointer border-none">
            {loading ? (
              <>
                <Loader2 size={16} className="animate-spin" /> Signing in…
              </>
            ) : (
              <>
                Log in <ArrowRight size={15} />
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
}
