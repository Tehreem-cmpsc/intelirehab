const LIGHT_PALETTE = {
  navy: "#093D42",
  navyMid: "#134D52",
  navyLight: "#1E5A61",
  teal: "#0D6E76",
  tealLight: "#E4F1F0",
  tealDim: "#073C41",
  tealBright: "#31E8C6",
  amber: "#E7A24C",
  amberLight: "#FDF1E4",
  amberDim: "#A76316",
  red: "#D96248",
  redLight: "#FBEAE5",
  green: "#4C9F70",
  greenLight: "#E9F5EC",
  slate50: "#F5F8F7",
  slate100: "#EEF4F3",
  slate200: "#DEE7E5",
  slate400: "#4C6360",
  slate500: "#5A6F6B",
  slate600: "#647B78",
  slate800: "#12242B",
  white: "#FFFFFF",
};

const DARK_PALETTE = {
  navy: "#0b2428",
  navyMid: "#12333a",
  navyLight: "#183b42",
  teal: "#31E8C6",
  tealLight: "rgba(49, 232, 198, 0.14)",
  tealDim: "#9FF3E8",
  tealBright: "#5FEEDB",
  amber: "#F0B86E",
  amberLight: "rgba(240, 184, 110, 0.16)",
  amberDim: "#F5CF95",
  red: "#F08070",
  redLight: "rgba(240, 128, 112, 0.16)",
  green: "#6CE09F",
  greenLight: "rgba(108, 224, 159, 0.16)",
  slate50: "#0f1f22",
  slate100: "#122b30",
  slate200: "rgba(255,255,255,0.10)",
  slate400: "rgba(255,255,255,0.78)",
  slate500: "rgba(255,255,255,0.86)",
  slate600: "rgba(255,255,255,0.92)",
  slate800: "#F7FCFB",
  white: "#FFFFFF",
};

export const THEME = { ...LIGHT_PALETTE };

export function setPhysioThemeMode(dark) {
  const palette = dark ? DARK_PALETTE : LIGHT_PALETTE;
  Object.entries(palette).forEach(([key, value]) => {
    THEME[key] = value;
  });
  return THEME;
}

export const STATUS_META = {
  active: { bg: THEME.tealLight, c: THEME.tealDim, label: "Active" },
  recovered: { bg: THEME.greenLight, c: THEME.green, label: "Recovered" },
  "at-risk": { bg: THEME.redLight, c: THEME.red, label: "At Risk" },
};
