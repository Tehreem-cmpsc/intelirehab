import React, { useState } from "react";
import { 
  ArrowRight, Activity, Cpu, Shield, Sparkles, 
  HelpCircle, ChevronDown, CheckCircle, TrendingUp,
  Clock, Award, Users, ChevronRight, Zap
} from "lucide-react";
import Logo, { LogoIcon } from "../components/Logo";

export default function LandingPage({ onGoLogin }) {
  // Simulator State
  const [angle, setAngle] = useState(65);
  const targetMin = 85;
  const targetMax = 115;
  const isWithinTarget = angle >= targetMin && angle <= targetMax;

  // Joint skeleton math (knee bending left)
  const length = 28;
  const rad = (angle * Math.PI) / 180;
  const tibiaX = 50 - length * Math.sin(rad);
  const tibiaY = 50 + length * Math.cos(rad);

  // Target Arc parameters at R=18
  const arcStartX = 50 - 18 * Math.sin((targetMin * Math.PI) / 180);
  const arcStartY = 50 + 18 * Math.cos((targetMin * Math.PI) / 180);
  const arcEndX = 50 - 18 * Math.sin((targetMax * Math.PI) / 180);
  const arcEndY = 50 + 18 * Math.cos((targetMax * Math.PI) / 180);
  const targetArcPath = `M ${arcStartX} ${arcStartY} A 18 18 0 0 1 ${arcEndX} ${arcEndY}`;

  // FAQ Accordion State
  const [activeFaq, setActiveFaq] = useState(null);

  const toggleFaq = (index) => {
    setActiveFaq(activeFaq === index ? null : index);
  };

  const faqs = [
    {
      q: "How does the wearable sensor integrate with the Inteli-Rehab portal?",
      a: "Our smart knee and elbow braces embed high-precision Inertial Measurement Units (IMUs). They sync real-time kinematic data via BLE (Bluetooth Low Energy) to the patient's smartphone app, which instantly transmits calibrated flexion/extension angles, angular velocity, and compliance directly to your administrator dashboard."
    },
    {
      q: "Is the Range of Motion (ROM) data fully objective?",
      a: "Yes. Traditional goniometers are prone to user-measurement errors of up to 10°-15°. Inteli-Rehab sensors continuously auto-calibrate based on gravitational vectors, recording absolute rotational trajectories accurate to within ±0.5°, providing clinicians with genuine clinical progress reports."
    },
    {
      q: "Can clinic admins configure and manage protocols for physiotherapists?",
      a: "As a Clinic Administrator, you have full control over the clinical roster. You can onboard physiotherapists, assign licenses, and view high-level clinical engagement statistics. Individual therapists manage their respective patients, set tailored ROM recovery thresholds, and prescribe exercise schedules."
    },
    {
      q: "What security compliance measures are in place for patient records?",
      a: "All records are structured under strict HIPAA guidelines. Transmission is encrypted using AES-256 and SSL/TLS protocols. Access control is role-based, ensuring only the patient's assigned clinician and authorized clinic administrators can view identity metrics."
    }
  ];

  return (
    <div className="cp-root min-h-screen flex flex-col selection:bg-[var(--primary-tint)] selection:text-[var(--primary-deep)]">
      {/* Premium Navbar */}
      <nav className="max-w-6xl w-full mx-auto flex items-center justify-between px-6 py-5 bg-transparent">
        <Logo size={36} light={true} showText={true} />
        <div className="flex items-center gap-6">
          <button 
            onClick={onGoLogin} 
            className="cp-btn-primary cp-focus rounded-xl px-6 py-2.5 text-[14px] flex items-center gap-2 cursor-pointer shadow-sm hover:shadow"
          >
            Sign In <ArrowRight size={15} />
          </button>
        </div>
      </nav>

      {/* Main Header / Hero */}
      <header className="relative overflow-hidden pt-12 pb-24 md:pt-16 md:pb-32 bg-[#093D42] text-white">
        {/* Abstract Background Vectors */}
        <div className="absolute inset-0 opacity-15 pointer-events-none">
          <svg className="cp-arc-spin absolute -right-24 -top-24 opacity-25" width="550" height="550" viewBox="0 0 520 520">
            <circle cx="260" cy="260" r="230" stroke="white" strokeWidth="2.5" fill="none" strokeDasharray="14 18" />
          </svg>
          <svg className="absolute -left-12 bottom-6 opacity-30" width="300" height="300" viewBox="0 0 300 300">
            <circle cx="150" cy="150" r="120" stroke="white" strokeWidth="1.5" fill="none" />
            <line x1="30" y1="150" x2="270" y2="150" stroke="white" strokeWidth="1.5" />
          </svg>
        </div>

        <div className="max-w-6xl mx-auto px-6 grid grid-cols-1 md:grid-cols-12 gap-12 items-center relative z-10">
          {/* Left Text Block */}
          <div className="md:col-span-7 text-left cp-rise">
            <div className="inline-flex items-center gap-2 bg-[#E7A24C]/15 text-[#F0B86E] px-3.5 py-1.5 rounded-full text-xs font-semibold tracking-wider uppercase mb-6 border border-[#E7A24C]/25">
              <Sparkles size={12} className="animate-pulse" /> Inteli-Rehab Portal
            </div>
            <h1 className="cp-display text-white font-bold text-[36px] sm:text-[46px] leading-[1.08] mb-6">
              Connect your clinicians. Track patient ROM objectively.
            </h1>
            <p className="text-white/80 text-[16px] sm:text-[18px] leading-relaxed mb-8 max-w-lg">
              Welcome to the Inteli-Rehab wearable network. Monitor real-time, sensor-driven orthopedic recovery curves and manage clinician and patient workflows in a single workspace.
            </p>
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4">
              <button 
                onClick={onGoLogin} 
                className="cp-focus inline-flex items-center justify-center gap-2 bg-white text-[#093D42] hover:bg-white/95 font-bold rounded-xl px-7 py-4 text-[15px] transition shadow-lg cursor-pointer"
              >
                Log In to Portal <ArrowRight size={17} />
              </button>
              <a 
                href="#demo" 
                className="inline-flex items-center justify-center gap-1.5 text-white/90 hover:text-white font-semibold text-[14px] px-4 py-3 transition"
              >
                Interactive ROM Demo <ChevronRight size={16} />
              </a>
            </div>
          </div>

          {/* Right Live ROM Simulator Card */}
          <div className="md:col-span-5 cp-fade-in">
            <div className="bg-[#112F35] border border-[#1e4a52] rounded-3xl p-6 shadow-2xl relative overflow-hidden">
              {/* Card Accent Lights */}
              <div className="absolute top-0 right-0 w-24 h-24 bg-[#31E8C6]/10 rounded-full blur-2xl pointer-events-none" />
              
              {/* Title & Connection Status */}
              <div className="flex items-center justify-between mb-6 pb-4 border-b border-white/10">
                <div className="text-left">
                  <div className="text-[12px] font-semibold text-[#31E8C6] tracking-wider uppercase">Live Wearable Monitor</div>
                  <div className="text-sm font-bold text-white/90">Knee Kinematics Simulator</div>
                </div>
                <span className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[#4C9F70]/20 text-[#6CE09F] text-xs font-semibold border border-[#4C9F70]/20">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#4C9F70] animate-ping" />
                  Synced
                </span>
              </div>

              {/* Interactive Joint Display */}
              <div className="grid grid-cols-2 gap-4 items-center mb-6">
                {/* SVG Knee Bone Outline */}
                <div className="flex justify-center bg-[#071F24] rounded-2xl p-4 border border-[#0d2d34] relative">
                  <span className="absolute top-2 left-2 text-[10px] uppercase font-mono text-white/40">Joint Schema</span>
                  
                  <svg width="100" height="100" viewBox="0 0 100 100" className="opacity-95">
                    {/* Grid Background */}
                    <path d="M 10 50 H 90 M 50 10 V 90" stroke="rgba(255,255,255,0.04)" strokeWidth="1" strokeDasharray="3 3" />
                    
                    {/* Target Range Highlight Sector */}
                    <path
                      d={targetArcPath}
                      stroke="rgba(76, 159, 112, 0.45)"
                      strokeWidth="8"
                      strokeLinecap="round"
                      fill="none"
                    />

                    {/* Joint Target Labels */}
                    <text x="12" y="80" fill="rgba(76, 159, 112, 0.9)" fontSize="7" fontWeight="bold">TARGET ZONE ({targetMin}°-{targetMax}°)</text>

                    {/* Upper Leg Bone (Femur) */}
                    <line x1="50" y1="18" x2="50" y2="50" stroke="#E4F1F0" strokeWidth="6" strokeLinecap="round" />
                    
                    {/* Knee joint connector */}
                    <circle cx="50" cy="50" r="5" fill="#31E8C6" stroke="#071F24" strokeWidth="1.5" />
                    
                    {/* Lower Leg Bone (Tibia) - Dynamic */}
                    <line 
                      x1="50" 
                      y1="50" 
                      x2={tibiaX} 
                      y2={tibiaY} 
                      stroke={isWithinTarget ? "#31E8C6" : "#E7A24C"} 
                      strokeWidth="6" 
                      strokeLinecap="round" 
                      style={{ transition: "all 0.05s ease-out" }}
                    />
                  </svg>
                </div>

                {/* Statistics Output */}
                <div className="text-left space-y-4">
                  <div className="bg-[#071F24]/50 border border-white/5 rounded-xl p-3.5">
                    <div className="text-[10px] text-white/50 font-semibold uppercase tracking-wider">Flexion Angle</div>
                    <div className="flex items-baseline gap-1 mt-1">
                      <span className="text-3xl font-extrabold text-[#31E8C6] tracking-tight">{angle}°</span>
                      <span className="text-[11px] text-white/60">Degrees</span>
                    </div>
                  </div>

                  <div className="bg-[#071F24]/50 border border-white/5 rounded-xl p-3.5">
                    <div className="text-[10px] text-white/50 font-semibold uppercase tracking-wider">Alignment Status</div>
                    <div className="mt-1">
                      {isWithinTarget ? (
                        <div className="text-xs font-bold text-[#6CE09F] flex items-center gap-1.5">
                          <CheckCircle size={14} /> Target Achieved
                        </div>
                      ) : (
                        <div className="text-xs font-bold text-[#E7A24C] flex items-center gap-1.5">
                          <Activity size={14} className="animate-pulse" /> Range Check
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              {/* Interactive Rotation Slider */}
              <div className="space-y-2 text-left bg-[#071F24]/30 rounded-xl p-4 border border-white/5">
                <div className="flex justify-between text-xs text-white/70">
                  <span>Full Extension (0°)</span>
                  <span>Max Flexion (135°)</span>
                </div>
                <input 
                  type="range" 
                  min="0" 
                  max="135" 
                  value={angle} 
                  onChange={(e) => setAngle(Number(e.target.value))}
                  className="w-full h-1.5 bg-[#173e45] rounded-lg appearance-none cursor-pointer accent-[#31E8C6] focus:outline-none"
                />
                <div className="text-[11px] text-white/50 text-center italic mt-1.5">
                  Drag the slider to preview simulated patient range-of-motion.
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Network Stats Banner */}
      <section className="max-w-6xl w-full mx-auto px-6 -mt-10 relative z-20 cp-fade-in">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
          {[
            { value: 92, label: "Partner Clinics", icon: Award, color: "text-[#0D6E76]" },
            { value: 142, label: "Physiotherapists Active", icon: Users, color: "text-[#E7A24C]" },
            { value: 68, label: "Average Recovery Rate", icon: TrendingUp, color: "text-[#4C9F70]", suffix: "%" },
          ].map((s, i) => {
            const Icon = s.icon;
            return (
              <div key={i} className="cp-card rounded-2xl p-6 flex items-center gap-5 shadow-lg bg-white border border-[#DEE7E5] text-left hover:scale-[1.01] transition-transform duration-250">
                <div className={`p-3.5 rounded-xl bg-[var(--bg)] ${s.color}`}>
                  <Icon size={24} />
                </div>
                <div>
                  <div className="cp-display font-extrabold text-2xl text-[#12242B] leading-none">
                    {s.value}{s.suffix || ""}
                  </div>
                  <div className="text-[13px] font-semibold text-[var(--muted)] mt-1">{s.label}</div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Detailed Value Proposition Section */}
      <section id="demo" className="max-w-6xl w-full mx-auto px-6 py-28 text-left">
        <div className="max-w-xl mb-16">
          <div className="cp-mono text-[12px] font-bold tracking-widest text-[#0D6E76] uppercase mb-3">Core Technology</div>
          <h2 className="cp-display font-bold text-[32px] text-[#12242B] leading-tight">
            Sensors replace speculation.
          </h2>
          <p className="text-[15px] text-[var(--muted)] mt-4 leading-relaxed">
            Inteli-Rehab translates raw kinematics into clinical intelligence. Give your physiotherapists direct access to objective tracking points.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {[
            {
              icon: Cpu,
              title: "Auto-Calibrating Wearables",
              desc: "Patients secure a light, sleeve-mounted IMU tracker. The tracker automatically measures motion vectors relative to spatial vectors, resolving goniometric errors."
            },
            {
              icon: Clock,
              title: "Continuous Progress Metrics",
              desc: "Track flexion and extension profiles daily. Eliminate patient memory bias, tracking progress over time directly in the secure dashboard."
            },
            {
              icon: Shield,
              title: "Enterprise Clinic Security",
              desc: "Complies with clinical data standards. Role-based encryption guards information, isolating patient databases between separate clinical branches."
            }
          ].map((feature, i) => {
            const Icon = feature.icon;
            return (
              <div key={i} className="bg-white border border-[#DEE7E5] rounded-2xl p-7 shadow-sm hover:shadow-md transition-shadow">
                <div className="w-12 h-12 rounded-xl bg-[#E4F1F0] text-[#0D6E76] flex items-center justify-center mb-6">
                  <Icon size={22} />
                </div>
                <h3 className="cp-display font-bold text-[18px] text-[#12242B] mb-3">{feature.title}</h3>
                <p className="text-[13.5px] text-[var(--muted)] leading-relaxed">{feature.desc}</p>
              </div>
            );
          })}
        </div>
      </section>

      {/* Accordion FAQ Section */}
      <section className="bg-white border-y border-[#DEE7E5] py-24">
        <div className="max-w-4xl mx-auto px-6 text-left">
          <div className="text-center max-w-lg mx-auto mb-16">
            <div className="cp-mono text-[11px] font-bold tracking-widest text-[#0D6E76] uppercase mb-3">Information</div>
            <h2 className="cp-display font-bold text-[30px] text-[#12242B]">Frequently Asked Questions</h2>
            <p className="text-[14px] text-[var(--muted)] mt-2">Answers to common queries regarding the Inteli-Rehab portal.</p>
          </div>

          <div className="space-y-4">
            {faqs.map((faq, idx) => (
              <div 
                key={idx} 
                className="border border-[#DEE7E5] rounded-xl overflow-hidden bg-[var(--bg)]/50 transition-colors"
              >
                <button
                  onClick={() => toggleFaq(idx)}
                  className="w-full flex items-center justify-between p-5 text-left font-bold text-[15px] text-[#12242B] hover:bg-[#E4F1F0]/40 transition-colors cursor-pointer"
                >
                  <span className="flex items-center gap-2.5">
                    <HelpCircle size={16} className="text-[#0D6E76]" />
                    {faq.q}
                  </span>
                  <ChevronDown 
                    size={16} 
                    className={`text-[var(--muted)] transition-transform duration-300 ${activeFaq === idx ? "rotate-180" : ""}`} 
                  />
                </button>
                <div 
                  className={`overflow-hidden transition-all duration-350 ease-in-out ${
                    activeFaq === idx ? "max-h-[300px] border-t border-[#DEE7E5]/70" : "max-h-0"
                  }`}
                >
                  <p className="p-5 text-[14px] leading-relaxed text-[var(--muted)] bg-white">
                    {faq.a}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* High-Fidelity Call-To-Action Banner */}
      <section className="max-w-6xl w-full mx-auto px-6 py-20">
        <div className="bg-[#093D42] rounded-3xl p-8 sm:p-12 text-center text-white relative overflow-hidden shadow-xl border border-white/5">
          <div className="absolute inset-0 opacity-10 pointer-events-none">
            <svg className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 opacity-30" width="400" height="400" viewBox="0 0 100 100">
              <circle cx="50" cy="50" r="45" stroke="white" strokeWidth="1" fill="none" strokeDasharray="3 3" />
            </svg>
          </div>
          
          <div className="relative z-10 max-w-xl mx-auto space-y-6">
            <div className="inline-flex items-center gap-1 bg-white/10 text-[#31E8C6] px-3.5 py-1 rounded-full text-xs font-semibold tracking-wider uppercase border border-white/10">
              <Zap size={12} /> Live Clinician Workspace
            </div>
            <h2 className="cp-display font-bold text-3xl sm:text-4xl">Ready to onboard your clinic?</h2>
            <p className="text-white/80 text-[15px] sm:text-[16px] leading-relaxed">
              Add your clinical team, set your license keys, and begin monitoring recovery paths immediately. No complex local setups required.
            </p>
            <div className="pt-4">
              <button 
                onClick={onGoLogin} 
                className="cp-focus inline-flex items-center gap-2 bg-white text-[#093D42] hover:bg-white/95 font-bold rounded-xl px-7 py-3.5 text-[15px] transition shadow-lg cursor-pointer"
              >
                Log In to Dashboard <ArrowRight size={16} />
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* Premium Footer */}
      <footer className="border-t border-[#DEE7E5] bg-white mt-auto">
        <div className="max-w-6xl w-full mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2 text-[13px] text-[var(--muted)] font-semibold">
            <LogoIcon size={20} light={false} /> Inteli-Rehab Portal
          </div>
          <div className="text-[12px] text-[var(--muted)]">
            © {new Date().getFullYear()} Inteli-Rehab. All Rights Reserved. A Smart Wearable Rehabilitation System.
          </div>
        </div>
      </footer>
    </div>
  );
}
