import { useState } from "react";
import { 
  ArrowRight, Activity, Zap, TrendingUp, 
  HelpCircle, ChevronDown, CheckCircle, BarChart3,
  Clock, Shield, Users, ChevronRight, Sparkles, Award
} from "lucide-react";
import { THEME } from "../../../infrastructure/physio/constants";
import { LogoFull } from "../components";

function PhysiotherapistLandingPage({ onGoLogin }) {
  const [angle, setAngle] = useState(65);
  const targetMin = 85;
  const targetMax = 115;
  const isWithinTarget = angle >= targetMin && angle <= targetMax;

  // Joint skeleton math (knee bending)
  const length = 28;
  const rad = (angle * Math.PI) / 180;
  const tibiaX = 50 - length * Math.sin(rad);
  const tibiaY = 50 + length * Math.cos(rad);

  // Target Arc
  const arcStartX = 50 - 18 * Math.sin((targetMin * Math.PI) / 180);
  const arcStartY = 50 + 18 * Math.cos((targetMin * Math.PI) / 180);
  const arcEndX = 50 - 18 * Math.sin((targetMax * Math.PI) / 180);
  const arcEndY = 50 + 18 * Math.cos((targetMax * Math.PI) / 180);
  const targetArcPath = `M ${arcStartX} ${arcStartY} A 18 18 0 0 1 ${arcEndX} ${arcEndY}`;

  // FAQ Accordion
  const [activeFaq, setActiveFaq] = useState(null);
  const toggleFaq = (index) => {
    setActiveFaq(activeFaq === index ? null : index);
  };

  const faqs = [
    {
      q: "How do I track my patients' ROM progress in real-time?",
      a: "Once patients are onboarded with their wearable sensors, all ROM data syncs automatically to your Inteli-Rehab dashboard. View flexion/extension curves, session history, and compliance metrics in real-time. No manual data entry required."
    },
    {
      q: "Can I assign exercises and set ROM targets for individual patients?",
      a: "Yes. For each patient, you can assign specific exercises, set ROM targets, define session frequency, and configure reps and sets. The system tracks compliance and alerts you when patients deviate from their prescribed plans."
    },
    {
      q: "What alerts notify me about at-risk patients?",
      a: "Inteli-Rehab automatically flags patients whose ROM trends are declining, who miss sessions, or who fall outside target ranges. You receive in-dashboard notifications and can send targeted warnings or adjust treatment protocols immediately."
    },
    {
      q: "Is patient data secure and HIPAA-compliant?",
      a: "All data transmission uses AES-256 encryption and SSL/TLS protocols. Access is role-based—only you and your clinic admin can view your patients' records. Complete HIPAA compliance with audit trails for regulatory oversight."
    },
    {
      q: "What training do I need to use the portal?",
      a: "Inteli-Rehab is designed for clinician usability. Most therapists are productive within 15–20 minutes. We provide interactive walkthroughs, video tutorials, and live support to ensure a smooth onboarding experience."
    }
  ];

  return (
    <div
      className="min-h-screen flex flex-col"
      style={{
        fontFamily: "'Inter','Segoe UI',sans-serif",
        backgroundColor: THEME.slate50,
        width: "100%",
        overflow: "hidden",
      }}
    >
      {/* Premium Navbar */}
      <nav
        style={{
          maxWidth: "1280px",
          width: "100%",
          margin: "0 auto",
          padding: "20px 24px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
        }}
      >
        <LogoFull dark={false} />
        <button
          onClick={onGoLogin}
          style={{
            background: THEME.teal,
            color: THEME.white,
            padding: "10px 24px",
            borderRadius: "10px",
            border: "none",
            fontSize: "14px",
            fontWeight: 600,
            cursor: "pointer",
            display: "flex",
            alignItems: "center",
            gap: "8px",
            transition: "all 0.2s",
          }}
          onMouseEnter={(e) => (e.target.style.opacity = "0.9")}
          onMouseLeave={(e) => (e.target.style.opacity = "1")}
        >
          Sign In <ArrowRight size={15} />
        </button>
      </nav>

      {/* Hero Section */}
      <header
        style={{
          position: "relative",
          overflow: "hidden",
          padding: "60px 24px 100px",
          background: THEME.navy,
          color: THEME.white,
        }}
      >
        {/* Background Decoration */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            opacity: 0.1,
            pointerEvents: "none",
          }}
        >
          <svg
            style={{
              position: "absolute",
              right: "-100px",
              top: "-100px",
              opacity: 0.25,
            }}
            width="550"
            height="550"
            viewBox="0 0 520 520"
          >
            <circle
              cx="260"
              cy="260"
              r="230"
              stroke="white"
              strokeWidth="2.5"
              fill="none"
              strokeDasharray="14 18"
            />
          </svg>
        </div>

        <div
          style={{
            maxWidth: "1280px",
            margin: "0 auto",
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "48px",
            alignItems: "center",
            position: "relative",
            zIndex: 10,
          }}
        >
          {/* Left Text Block */}
          <div>
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "8px",
                background: `${THEME.amber}15`,
                color: THEME.amber,
                padding: "8px 16px",
                borderRadius: "20px",
                fontSize: "11px",
                fontWeight: 600,
                letterSpacing: "0.5px",
                textTransform: "uppercase",
                marginBottom: "24px",
                border: `1px solid ${THEME.amber}40`,
              }}
            >
              <Sparkles size={12} /> Physiotherapist Portal
            </div>
            <h1
              style={{
                fontSize: "42px",
                fontWeight: 800,
                lineHeight: 1.1,
                marginBottom: "24px",
                color: THEME.white,
              }}
            >
              Objective ROM tracking. Powered by wearables.
            </h1>
            <p
              style={{
                fontSize: "16px",
                lineHeight: 1.6,
                color: `${THEME.white}cc`,
                marginBottom: "32px",
                maxWidth: "500px",
              }}
            >
              Monitor your patients' recovery with precision sensors. Track Range of Motion in real-time, prescribe evidence-based exercises, and make data-driven clinical decisions.
            </p>
            <button
              onClick={onGoLogin}
              style={{
                background: THEME.white,
                color: THEME.navy,
                padding: "14px 28px",
                borderRadius: "10px",
                border: "none",
                fontSize: "15px",
                fontWeight: 700,
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                gap: "8px",
                boxShadow: "0 8px 24px rgba(0,0,0,0.15)",
                transition: "all 0.2s",
              }}
              onMouseEnter={(e) => (e.target.style.transform = "translateY(-2px)")}
              onMouseLeave={(e) => (e.target.style.transform = "translateY(0)")}
            >
              Sign In to Dashboard <ArrowRight size={17} />
            </button>
          </div>

          {/* Right Interactive Simulator */}
          <div
            style={{
              background: THEME.navyLight,
              border: `1px solid ${THEME.slate200}20`,
              borderRadius: "24px",
              padding: "24px",
              boxShadow: "0 20px 60px rgba(0,0,0,0.3)",
              position: "relative",
              overflow: "hidden",
            }}
          >
            <div
              style={{
                position: "absolute",
                top: 0,
                right: 0,
                width: "96px",
                height: "96px",
                background: `${THEME.teal}15`,
                borderRadius: "50%",
                filter: "blur(32px)",
                pointerEvents: "none",
              }}
            />

            {/* Title & Status */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                marginBottom: "24px",
                paddingBottom: "16px",
                borderBottom: `1px solid ${THEME.white}10`,
              }}
            >
              <div>
                <div
                  style={{
                    fontSize: "10px",
                    fontWeight: 600,
                    color: THEME.teal,
                    letterSpacing: "0.5px",
                    textTransform: "uppercase",
                  }}
                >
                  Live Wearable Monitor
                </div>
                <div
                  style={{
                    fontSize: "14px",
                    fontWeight: 700,
                    color: `${THEME.white}ee`,
                  }}
                >
                  Knee ROM Simulator
                </div>
              </div>
              <span
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "8px",
                  padding: "6px 12px",
                  borderRadius: "20px",
                  background: `${THEME.green}20`,
                  color: THEME.green,
                  fontSize: "11px",
                  fontWeight: 600,
                  border: `1px solid ${THEME.green}30`,
                }}
              >
                <span
                  style={{
                    width: "6px",
                    height: "6px",
                    borderRadius: "50%",
                    background: THEME.green,
                    animation: "pulse 2s infinite",
                  }}
                />
                Synced
              </span>
            </div>

            {/* Joint Display */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "16px",
                alignItems: "center",
                marginBottom: "24px",
              }}
            >
              {/* SVG */}
              <div
                style={{
                  display: "flex",
                  justifyContent: "center",
                  background: THEME.slate100,
                  borderRadius: "16px",
                  padding: "16px",
                  border: `1px solid ${THEME.slate200}`,
                }}
              >
                <svg width="100" height="100" viewBox="0 0 100 100" style={{ opacity: 0.95 }}>
                  {/* Grid */}
                  <path
                    d="M 10 50 H 90 M 50 10 V 90"
                    stroke={`${THEME.slate800}10`}
                    strokeWidth="1"
                    strokeDasharray="3 3"
                  />

                  {/* Target Arc */}
                  <path
                    d={targetArcPath}
                    stroke={`${THEME.teal}70`}
                    strokeWidth="8"
                    strokeLinecap="round"
                    fill="none"
                  />

                  {/* Femur */}
                  <line
                    x1="50"
                    y1="18"
                    x2="50"
                    y2="50"
                    stroke={THEME.slate800}
                    strokeWidth="6"
                    strokeLinecap="round"
                  />

                  {/* Joint */}
                  <circle
                    cx="50"
                    cy="50"
                    r="5"
                    fill={THEME.teal}
                    stroke={THEME.white}
                    strokeWidth="1.5"
                  />

                  {/* Tibia Dynamic */}
                  <line
                    x1="50"
                    y1="50"
                    x2={tibiaX}
                    y2={tibiaY}
                    stroke={isWithinTarget ? THEME.teal : THEME.amber}
                    strokeWidth="6"
                    strokeLinecap="round"
                    style={{ transition: "all 0.05s ease-out" }}
                  />
                </svg>
              </div>

              {/* Stats */}
              <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                <div
                  style={{
                    background: `${THEME.white}08`,
                    border: `1px solid ${THEME.white}10`,
                    borderRadius: "12px",
                    padding: "16px",
                  }}
                >
                  <div
                    style={{
                      fontSize: "10px",
                      color: `${THEME.white}66`,
                      fontWeight: 600,
                      textTransform: "uppercase",
                      letterSpacing: "0.5px",
                    }}
                  >
                    Flexion Angle
                  </div>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "baseline",
                      gap: "4px",
                      marginTop: "8px",
                    }}
                  >
                    <span
                      style={{
                        fontSize: "28px",
                        fontWeight: 800,
                        color: THEME.teal,
                      }}
                    >
                      {angle}°
                    </span>
                    <span style={{ fontSize: "11px", color: `${THEME.white}66` }}>
                      Degrees
                    </span>
                  </div>
                </div>

                <div
                  style={{
                    background: `${THEME.white}08`,
                    border: `1px solid ${THEME.white}10`,
                    borderRadius: "12px",
                    padding: "16px",
                  }}
                >
                  <div
                    style={{
                      fontSize: "10px",
                      color: `${THEME.white}66`,
                      fontWeight: 600,
                      textTransform: "uppercase",
                      letterSpacing: "0.5px",
                    }}
                  >
                    Status
                  </div>
                  <div style={{ marginTop: "8px" }}>
                    {isWithinTarget ? (
                      <div
                        style={{
                          fontSize: "12px",
                          fontWeight: 700,
                          color: THEME.green,
                          display: "flex",
                          alignItems: "center",
                          gap: "8px",
                        }}
                      >
                        <CheckCircle size={14} /> Target Achieved
                      </div>
                    ) : (
                      <div
                        style={{
                          fontSize: "12px",
                          fontWeight: 700,
                          color: THEME.amber,
                          display: "flex",
                          alignItems: "center",
                          gap: "8px",
                        }}
                      >
                        <Activity size={14} /> Range Check
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Slider */}
            <div
              style={{
                background: `${THEME.white}05`,
                borderRadius: "12px",
                padding: "16px",
                border: `1px solid ${THEME.white}10`,
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  fontSize: "11px",
                  color: `${THEME.white}77`,
                  marginBottom: "12px",
                }}
              >
                <span>Extension (0°)</span>
                <span>Flexion (135°)</span>
              </div>
              <input
                type="range"
                min="0"
                max="135"
                value={angle}
                onChange={(e) => setAngle(Number(e.target.value))}
                style={{
                  width: "100%",
                  height: "6px",
                  borderRadius: "8px",
                  background: `${THEME.slate600}40`,
                  outline: "none",
                  cursor: "pointer",
                  accentColor: THEME.teal,
                }}
              />
              <div
                style={{
                  fontSize: "10px",
                  color: `${THEME.white}55`,
                  marginTop: "10px",
                  fontStyle: "italic",
                  textAlign: "center",
                }}
              >
                Preview patient ROM data interactively
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Stats Banner */}
      <section
        style={{
          maxWidth: "1280px",
          width: "100%",
          margin: "-40px auto 0",
          padding: "0 24px",
          position: "relative",
          zIndex: 20,
        }}
      >
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
            gap: "24px",
          }}
        >
          {[
            {
              value: "4,200+",
              label: "Patients Monitored",
              icon: Users,
              color: THEME.teal,
            },
            {
              value: "142",
              label: "Active Therapists",
              icon: Award,
              color: THEME.amber,
            },
            {
              value: "78%",
              label: "Avg Recovery Rate",
              icon: TrendingUp,
              color: THEME.green,
            },
          ].map((stat, i) => {
            const Icon = stat.icon;
            return (
              <div
                key={i}
                style={{
                  background: THEME.white,
                  borderRadius: "16px",
                  padding: "24px",
                  boxShadow: "0 4px 12px rgba(0,0,0,0.05)",
                  border: `1px solid ${THEME.slate200}`,
                  display: "flex",
                  alignItems: "center",
                  gap: "20px",
                  transition: "all 0.2s",
                  cursor: "pointer",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.boxShadow = "0 8px 24px rgba(0,0,0,0.1)";
                  e.currentTarget.style.transform = "translateY(-2px)";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.boxShadow = "0 4px 12px rgba(0,0,0,0.05)";
                  e.currentTarget.style.transform = "translateY(0)";
                }}
              >
                <div
                  style={{
                    padding: "14px",
                    borderRadius: "12px",
                    background: `${stat.color}15`,
                    color: stat.color,
                  }}
                >
                  <Icon size={24} />
                </div>
                <div>
                  <div
                    style={{
                      fontSize: "24px",
                      fontWeight: 800,
                      color: THEME.slate800,
                    }}
                  >
                    {stat.value}
                  </div>
                  <div
                    style={{
                      fontSize: "13px",
                      fontWeight: 600,
                      color: THEME.slate500,
                    }}
                  >
                    {stat.label}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Features Section */}
      <section
        style={{
          maxWidth: "1280px",
          width: "100%",
          margin: "0 auto",
          padding: "80px 24px",
        }}
      >
        <div style={{ maxWidth: "600px", marginBottom: "60px" }}>
          <div
            style={{
              fontSize: "11px",
              fontWeight: 700,
              letterSpacing: "1px",
              color: THEME.teal,
              textTransform: "uppercase",
              marginBottom: "12px",
            }}
          >
            Therapist Essentials
          </div>
          <h2
            style={{
              fontSize: "32px",
              fontWeight: 800,
              color: THEME.slate800,
              lineHeight: 1.2,
            }}
          >
            Make data-driven clinical decisions.
          </h2>
          <p
            style={{
              fontSize: "15px",
              color: THEME.slate500,
              marginTop: "16px",
              lineHeight: 1.6,
            }}
          >
            Inteli-Rehab gives you the objective metrics you need to optimize treatment plans and accelerate patient recovery.
          </p>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
            gap: "24px",
          }}
        >
          {[
            {
              icon: Activity,
              title: "Real-Time ROM Tracking",
              desc: "Monitor flexion/extension curves daily with sensor accuracy. Eliminate guesswork—track objective progress at every session.",
            },
            {
              icon: Zap,
              title: "Smart Exercise Assignment",
              desc: "Prescribe evidence-based exercises with ROM targets, reps, sets, and frequency. The system tracks compliance automatically.",
            },
            {
              icon: BarChart3,
              title: "Compliance & Analytics",
              desc: "View session completion rates, EMG activation profiles, and trend analysis. Adjust protocols based on real data.",
            },
            {
              icon: Clock,
              title: "Session Management",
              desc: "Schedule patient sessions, track completion, and review ROM progress for each session with interactive charts.",
            },
            {
              icon: Shield,
              title: "Patient Privacy",
              desc: "HIPAA-compliant data storage with encryption. Role-based access ensures only authorized clinicians view patient data.",
            },
            {
              icon: Users,
              title: "Easy Onboarding",
              desc: "Quick setup for you and your patients. Most therapists are productive within 15–20 minutes of first use.",
            },
          ].map((feature, i) => {
            const Icon = feature.icon;
            return (
              <div
                key={i}
                style={{
                  background: THEME.white,
                  border: `1px solid ${THEME.slate200}`,
                  borderRadius: "16px",
                  padding: "28px",
                  transition: "all 0.2s",
                  cursor: "pointer",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.boxShadow = "0 8px 24px rgba(0,0,0,0.08)";
                  e.currentTarget.style.borderColor = THEME.teal;
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.boxShadow = "none";
                  e.currentTarget.style.borderColor = THEME.slate200;
                }}
              >
                <div
                  style={{
                    width: "48px",
                    height: "48px",
                    borderRadius: "12px",
                    background: `${THEME.teal}15`,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    color: THEME.teal,
                    marginBottom: "16px",
                  }}
                >
                  <Icon size={24} />
                </div>
                <h3
                  style={{
                    fontSize: "16px",
                    fontWeight: 700,
                    color: THEME.slate800,
                    marginBottom: "8px",
                  }}
                >
                  {feature.title}
                </h3>
                <p
                  style={{
                    fontSize: "13.5px",
                    color: THEME.slate500,
                    lineHeight: 1.6,
                  }}
                >
                  {feature.desc}
                </p>
              </div>
            );
          })}
        </div>
      </section>

      {/* FAQ Section */}
      <section
        style={{
          background: THEME.white,
          borderTop: `1px solid ${THEME.slate200}`,
          borderBottom: `1px solid ${THEME.slate200}`,
          padding: "80px 24px",
        }}
      >
        <div style={{ maxWidth: "900px", margin: "0 auto" }}>
          <div style={{ textAlign: "center", marginBottom: "60px" }}>
            <div
              style={{
                fontSize: "11px",
                fontWeight: 700,
                letterSpacing: "1px",
                color: THEME.teal,
                textTransform: "uppercase",
                marginBottom: "12px",
              }}
            >
              Questions?
            </div>
            <h2
              style={{
                fontSize: "30px",
                fontWeight: 800,
                color: THEME.slate800,
              }}
            >
              Frequently Asked Questions
            </h2>
            <p
              style={{
                fontSize: "14px",
                color: THEME.slate500,
                marginTop: "12px",
              }}
            >
              Everything you need to know about Inteli-Rehab for physiotherapists.
            </p>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            {faqs.map((faq, idx) => (
              <div
                key={idx}
                style={{
                  border: `1px solid ${THEME.slate200}`,
                  borderRadius: "12px",
                  overflow: "hidden",
                  background: THEME.white,
                }}
              >
                <button
                  onClick={() => toggleFaq(idx)}
                  style={{
                    width: "100%",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    padding: "20px",
                    textAlign: "left",
                    fontWeight: 600,
                    fontSize: "15px",
                    color: THEME.slate800,
                    background: "transparent",
                    border: "none",
                    cursor: "pointer",
                    transition: "background 0.2s",
                  }}
                  onMouseEnter={(e) =>
                    (e.currentTarget.style.background = `${THEME.teal}05`)
                  }
                  onMouseLeave={(e) =>
                    (e.currentTarget.style.background = "transparent")
                  }
                >
                  <span style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                    <HelpCircle size={16} color={THEME.teal} />
                    {faq.q}
                  </span>
                  <ChevronDown
                    size={16}
                    color={THEME.slate500}
                    style={{
                      transition: "transform 0.3s",
                      transform: activeFaq === idx ? "rotate(180deg)" : "rotate(0deg)",
                    }}
                  />
                </button>
                {activeFaq === idx && (
                  <div
                    style={{
                      padding: "20px",
                      borderTop: `1px solid ${THEME.slate200}`,
                      background: THEME.slate50,
                    }}
                  >
                    <p
                      style={{
                        fontSize: "14px",
                        lineHeight: 1.7,
                        color: THEME.slate600,
                      }}
                    >
                      {faq.a}
                    </p>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Banner */}
      <section
        style={{
          maxWidth: "1280px",
          width: "100%",
          margin: "0 auto",
          padding: "60px 24px",
        }}
      >
        <div
          style={{
            background: THEME.navy,
            borderRadius: "24px",
            padding: "48px",
            textAlign: "center",
            color: THEME.white,
            position: "relative",
            overflow: "hidden",
            border: `1px solid ${THEME.white}10`,
            boxShadow: "0 20px 60px rgba(0,0,0,0.2)",
          }}
        >
          <div
            style={{
              maxWidth: "600px",
              margin: "0 auto",
              display: "flex",
              flexDirection: "column",
              gap: "24px",
              position: "relative",
              zIndex: 10,
            }}
          >
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "8px",
                background: `${THEME.white}10`,
                color: THEME.teal,
                padding: "8px 16px",
                borderRadius: "20px",
                fontSize: "12px",
                fontWeight: 600,
                letterSpacing: "0.5px",
                textTransform: "uppercase",
                border: `1px solid ${THEME.white}20`,
                margin: "0 auto",
              }}
            >
              <Zap size={12} /> Join the Network
            </div>
            <h2
              style={{
                fontSize: "32px",
                fontWeight: 800,
              }}
            >
              Ready to transform your practice?
            </h2>
            <p
              style={{
                fontSize: "15px",
                lineHeight: 1.6,
                color: `${THEME.white}dd`,
              }}
            >
              Start using Inteli-Rehab today. Get real-time ROM data, streamline your workflow, and deliver better outcomes for your patients.
            </p>
            <button
              onClick={onGoLogin}
              style={{
                background: THEME.white,
                color: THEME.navy,
                padding: "14px 28px",
                borderRadius: "10px",
                border: "none",
                fontSize: "15px",
                fontWeight: 700,
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                gap: "8px",
                transition: "all 0.2s",
              }}
              onMouseEnter={(e) => (e.target.style.opacity = "0.9")}
              onMouseLeave={(e) => (e.target.style.opacity = "1")}
            >
              Sign In <ArrowRight size={16} />
            </button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer
        style={{
          borderTop: `1px solid ${THEME.slate200}`,
          background: THEME.white,
          marginTop: "auto",
        }}
      >
        <div
          style={{
            maxWidth: "1280px",
            width: "100%",
            margin: "0 auto",
            padding: "32px 24px",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            textAlign: "center",
            gap: "12px",
          }}
        >
          <LogoFull dark={false} />
          <div
            style={{
              fontSize: "12px",
              color: THEME.slate500,
            }}
          >
            © {new Date().getFullYear()} Inteli-Rehab. Empowering physiotherapists with wearable technology.
          </div>
        </div>
      </footer>

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </div>
  );
}

export default PhysiotherapistLandingPage;
