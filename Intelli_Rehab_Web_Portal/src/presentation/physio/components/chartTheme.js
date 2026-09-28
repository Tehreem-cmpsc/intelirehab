import { THEME } from "../../../infrastructure/physio/constants";

// Recharts' default tooltip is a white box with inherited text colour —
// in dark mode that's near-white text on white. Spread this onto every
// <Tooltip> so it follows the current theme.
export function tooltipProps() {
  return {
    contentStyle: {
      borderRadius: 9,
      border: `1px solid ${THEME.slate200}`,
      background: THEME.surface,
      color: THEME.slate800,
      fontSize: 12,
      boxShadow: "0 6px 20px rgba(0,0,0,0.18)",
    },
    labelStyle: { color: THEME.slate800, fontWeight: 600 },
    itemStyle: { color: THEME.slate600 },
    cursor: { fill: THEME.tealLight, opacity: 0.5 },
  };
}

// Axis tick text, readable in both themes.
export function axisTick() {
  return { fontSize: 11, fill: THEME.slate400 };
}

// Standard page padding: tighter on phones.
export function pagePadding(isMobile) {
  return isMobile ? "20px 16px 32px" : "28px 32px";
}
