import { useState } from "react";
import { Lock, ShieldCheck, Loader2, ArrowRight, ChevronLeft, Activity, TrendingUp, Users } from "lucide-react";
import { THEME, DEMO_CREDENTIALS } from "../../../infrastructure/physio/constants";
import { Logo } from "../components";

function LoginPage({ onLogin, onBackToLanding }) {
  const [id, setId] = useState(DEMO_CREDENTIALS.id);
  const [pass, setPass] = useState(DEMO_CREDENTIALS.password);
  const [err, setErr] = useState("");
  const [loading, setLoading] = useState(false);

  const submit = (e) => {
    e.preventDefault();
    if (!id || !pass) {
      setErr("Please enter both your ID and password.");
      return;
    }

    setLoading(true);
    setErr("");

    setTimeout(() => {
      if (id === DEMO_CREDENTIALS.id && pass === DEMO_CREDENTIALS.password) {
        onLogin();
      } else {
        setErr("Unrecognised physiotherapist ID or password.");
        setLoading(false);
      }
    }, 900);
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        fontFamily: "'Inter','Segoe UI',sans-serif",
        overflow: "hidden",
      }}
    >
      {/* Left Side - Hidden on Mobile */}
      <div
        style={{
          display: "none",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "48px",
          background: `linear-gradient(160deg, ${THEME.navy} 0%, ${THEME.teal}20 100%)`,
          position: "relative",
          "@media (min-width: 768px)": {
            display: "flex",
          },
        }}
        className="hidden md:flex"
      >
        {/* Background decoration */}
        <svg
          style={{
            position: "absolute",
            left: "-128px",
            bottom: "-128px",
            opacity: 0.15,
          }}
          width="480"
          height="480"
          viewBox="0 0 480 480"
        >
          <circle
            cx="240"
            cy="240"
            r="210"
            stroke="white"
            strokeWidth="2"
            fill="none"
            strokeDasharray="10 14"
          />
        </svg>

        {/* Logo */}
        <div style={{ position: "relative", zIndex: 10 }}>
          <Logo size={36} dark={false} />
        </div>

        {/* Testimonial Section */}
        <div style={{ position: "relative", zIndex: 10 }}>
          {/* Stats */}
          <div style={{ display: "flex", flexDirection: "column", gap: "16px", marginBottom: "32px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "12px", color: THEME.white }}>
              <div style={{ padding: "10px", background: `${THEME.teal}30`, borderRadius: "10px" }}>
                <Users size={20} />
              </div>
              <div>
                <div style={{ fontSize: "18px", fontWeight: 800 }}>142</div>
                <div style={{ fontSize: "12px", color: `${THEME.white}aa` }}>Active Physiotherapists</div>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "12px", color: THEME.white }}>
              <div style={{ padding: "10px", background: `${THEME.green}30`, borderRadius: "10px" }}>
                <TrendingUp size={20} />
              </div>
              <div>
                <div style={{ fontSize: "18px", fontWeight: 800 }}>78%</div>
                <div style={{ fontSize: "12px", color: `${THEME.white}aa` }}>Avg Recovery Rate</div>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: "12px", color: THEME.white }}>
              <div style={{ padding: "10px", background: `${THEME.amber}30`, borderRadius: "10px" }}>
                <Activity size={20} />
              </div>
              <div>
                <div style={{ fontSize: "18px", fontWeight: 800 }}>4,200+</div>
                <div style={{ fontSize: "12px", color: `${THEME.white}aa` }}>Patients Monitored</div>
              </div>
            </div>
          </div>

          {/* Testimonial */}
          <p style={{ fontSize: "18px", lineHeight: 1.6, color: THEME.white, marginBottom: "16px", fontWeight: 500, maxWidth: "300px" }}>
            "Real-time ROM tracking transformed how we monitor patient progress and optimize treatment plans."
          </p>
          <p style={{ fontSize: "12px", color: `${THEME.white}77` }}>
            Physiotherapist, Partner Clinic
          </p>
        </div>

        {/* Copyright */}
        <div style={{ color: `${THEME.white}55`, fontSize: "11px", position: "relative", zIndex: 10 }}>
          © Inteli-Rehab — Smart Rehabilitation System
        </div>
      </div>

      {/* Right Side - Login Form */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: "32px",
          background: THEME.slate50,
          position: "relative",
        }}
      >
        {/* Back Button */}
        {onBackToLanding && (
          <button
            onClick={onBackToLanding}
            style={{
              position: "absolute",
              top: 20,
              left: 20,
              background: `${THEME.teal}15`,
              color: THEME.teal,
              border: `1px solid ${THEME.teal}40`,
              borderRadius: 8,
              padding: "8px 12px",
              display: "flex",
              alignItems: "center",
              gap: "6px",
              fontSize: 13,
              fontWeight: 600,
              cursor: "pointer",
              transition: "all 0.2s",
            }}
            onMouseEnter={(e) => {
              e.target.style.background = `${THEME.teal}25`;
              e.target.style.borderColor = `${THEME.teal}80`;
            }}
            onMouseLeave={(e) => {
              e.target.style.background = `${THEME.teal}15`;
              e.target.style.borderColor = `${THEME.teal}40`;
            }}
          >
            <ChevronLeft size={16} /> Back
          </button>
        )}

        <form onSubmit={submit} style={{ width: "100%", maxWidth: "400px" }}>
          {/* Mobile Logo */}
          <div style={{ display: "flex", alignItems: "center", marginBottom: "24px", gap: "12px" }} className="md:hidden">
            <Logo size={32} dark={false} />
            <div>
              <div style={{ fontSize: "16px", fontWeight: 800, color: THEME.navy }}>
                Inteli<span style={{ color: THEME.teal }}>Rehab</span>
              </div>
            </div>
          </div>

          {/* Heading */}
          <h1 style={{ fontSize: "24px", fontWeight: 800, color: THEME.slate800, marginBottom: "8px" }}>
            Welcome back
          </h1>
          <p style={{ fontSize: "14px", color: THEME.slate500, marginBottom: "24px" }}>
            Log in to monitor your patients' recovery.
          </p>

          {/* ID Input */}
          <label style={{ display: "block", fontSize: "12px", fontWeight: 600, color: THEME.slate600, marginBottom: "6px" }}>
            PHYSIOTHERAPIST ID
          </label>
          <div style={{ position: "relative", marginBottom: "16px" }}>
            <Lock size={16} style={{ position: "absolute", left: "12px", top: "50%", transform: "translateY(-50%)", color: THEME.slate500 }} />
            <input
              type="text"
              value={id}
              onChange={(e) => setId(e.target.value)}
              placeholder="e.g. DR-AHMED-001"
              style={{
                width: "100%",
                padding: "10px 12px 10px 40px",
                border: `1.5px solid ${THEME.slate200}`,
                borderRadius: "8px",
                fontSize: "14px",
                outline: "none",
                boxSizing: "border-box",
                transition: "border-color 0.2s",
              }}
              onFocus={(e) => (e.target.style.borderColor = THEME.teal)}
              onBlur={(e) => (e.target.style.borderColor = THEME.slate200)}
              onKeyDown={(e) => e.key === "Enter" && submit(e)}
            />
          </div>

          {/* Password Input */}
          <label style={{ display: "block", fontSize: "12px", fontWeight: 600, color: THEME.slate600, marginBottom: "6px" }}>
            PASSWORD
          </label>
          <div style={{ position: "relative", marginBottom: "8px" }}>
            <Lock size={16} style={{ position: "absolute", left: "12px", top: "50%", transform: "translateY(-50%)", color: THEME.slate500 }} />
            <input
              type="password"
              value={pass}
              onChange={(e) => setPass(e.target.value)}
              placeholder="••••••••"
              style={{
                width: "100%",
                padding: "10px 12px 10px 40px",
                border: `1.5px solid ${THEME.slate200}`,
                borderRadius: "8px",
                fontSize: "14px",
                outline: "none",
                boxSizing: "border-box",
                transition: "border-color 0.2s",
              }}
              onFocus={(e) => (e.target.style.borderColor = THEME.teal)}
              onBlur={(e) => (e.target.style.borderColor = THEME.slate200)}
              onKeyDown={(e) => e.key === "Enter" && submit(e)}
            />
          </div>

          {/* Demo Info */}
          <p style={{ fontSize: "12px", color: THEME.slate500, marginBottom: "16px", display: "flex", alignItems: "center", gap: "6px" }}>
            <ShieldCheck size={13} /> Demo prototype — use credentials below.
          </p>

          {/* Error Message */}
          {err && (
            <div
              style={{
                background: THEME.redLight,
                color: THEME.red,
                borderRadius: 8,
                padding: "10px 14px",
                fontSize: 13,
                marginBottom: 12,
              }}
            >
              {err}
            </div>
          )}

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            style={{
              width: "100%",
              padding: "12px",
              background: loading ? THEME.slate200 : THEME.teal,
              border: "none",
              borderRadius: 8,
              color: THEME.white,
              fontWeight: 700,
              fontSize: 14,
              cursor: loading ? "default" : "pointer",
              marginBottom: 16,
              transition: "all 0.2s",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: "8px",
            }}
          >
            {loading ? (
              <>
                <Loader2 size={16} style={{ animation: "spin 1s linear infinite" }} /> Signing in…
              </>
            ) : (
              <>
                Log in <ArrowRight size={15} />
              </>
            )}
          </button>

          {/* Demo Credentials */}
          <div
            style={{
              background: THEME.white,
              border: `1px solid ${THEME.slate200}`,
              borderRadius: 8,
              padding: "12px",
              fontSize: 12,
              color: THEME.slate500,
              textAlign: "center",
            }}
          >
            Demo ID: <strong>{DEMO_CREDENTIALS.id}</strong> / Pass: <strong>{DEMO_CREDENTIALS.password}</strong>
          </div>
        </form>
      </div>

      <style>{`
        @media (max-width: 768px) {
          div {
            grid-template-columns: 1fr;
          }
        }
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}

export default LoginPage;
