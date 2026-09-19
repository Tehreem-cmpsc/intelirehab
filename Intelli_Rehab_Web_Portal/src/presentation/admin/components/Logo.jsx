import React from "react";

const LIGHT_COLORS = {
  background: "#E4FAF6",
  ring: "#00B9A0",
  accent: "#1CBDAF",
  stroke: "#0F5D63",
  textPrimary: "#0E323D",
  textSecondary: "#4A6B78",
};

const DARK_COLORS = {
  background: "#0D2B38",
  ring: "#144F5A",
  accent: "#33E6D0",
  stroke: "#81F6E8",
  textPrimary: "#FFFFFF",
  textSecondary: "rgba(255,255,255,0.72)",
};

export function LogoIcon({ size = 40, light = false }) {
  const colors = light ? LIGHT_COLORS : DARK_COLORS;
  const radius = 44;
  const center = 50;

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className="inline-block"
    >
      <circle cx={center} cy={center} r={radius} fill={colors.background} />
      <circle
        cx={center}
        cy={center}
        r={radius - 10}
        stroke={colors.ring}
        strokeWidth="3"
        opacity="0.8"
      />
      <path
        d="M 18 60 L 28 60 L 33 46 L 39 74 L 47 46 L 52 66 L 58 55 L 67 55 C 72 55, 78 52, 82 47"
        stroke={colors.accent}
        strokeWidth="6"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
      <path
        d="M 20 52 C 28 42, 42 36, 54 44 C 62 50, 72 60, 76 68"
        stroke={colors.stroke}
        strokeWidth="4"
        strokeLinecap="round"
        fill="none"
        opacity="0.9"
      />
    </svg>
  );
}

export default function Logo({ size = 40, light = false, showText = true }) {
  const colors = light ? LIGHT_COLORS : DARK_COLORS;

  return (
    <div className="flex items-center gap-3">
      <LogoIcon size={size} light={light} />
      {showText && (
        <div className="leading-tight text-left">
          <div className="cp-display font-black tracking-tight text-[18px]" style={{ color: colors.textPrimary }}>
            <span style={{ color: colors.textPrimary }}>Inteli</span>
            <span style={{ color: colors.accent }}>Rehab</span>
          </div>
          <div className="text-[9px] font-semibold tracking-[0.18em] uppercase -mt-0.5" style={{ color: colors.textSecondary }}>
            Smart Rehabilitation
          </div>
        </div>
      )}
    </div>
  );
}
