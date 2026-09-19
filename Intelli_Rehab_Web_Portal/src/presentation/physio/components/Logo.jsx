import { THEME } from "../../../infrastructure/physio/constants";

function Logo({ size = 32, dark = false }) {
  const circleBg = dark ? THEME.teal : THEME.teal;
  const iconColor = THEME.white;
  const strokeWidth = Math.max(1.5, size * 0.08);

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      style={{ display: "block" }}
    >
      {/* Circular background */}
      <circle
        cx="32"
        cy="32"
        r="30"
        fill={circleBg}
        stroke={circleBg}
        strokeWidth="2"
      />

      {/* Heartbeat/Waveform icon */}
      <g stroke={iconColor} strokeWidth={strokeWidth} fill="none" strokeLinecap="round" strokeLinejoin="round">
        {/* Left baseline */}
        <path d="M 10 32 L 18 32" />
        
        {/* Initial heartbeat peak */}
        <path d="M 18 32 L 22 20 L 26 32" />
        
        {/* Middle valley and peak */}
        <path d="M 26 32 L 30 40 L 34 32" />
        
        {/* Large peak (main heartbeat) */}
        <path d="M 34 32 L 40 10 L 46 32" />
        
        {/* Right baseline */}
        <path d="M 46 32 L 54 32" />
      </g>
    </svg>
  );
}

export default Logo;
