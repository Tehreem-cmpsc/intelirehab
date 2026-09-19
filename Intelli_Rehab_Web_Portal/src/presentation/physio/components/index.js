import Card from "./Card";
import Badge from "./Badge";
import SectionHead from "./SectionHead";
import RomBar from "./RomBar";
import Logo from "./Logo";
import LogoFull from "./LogoFull";
import { THEME } from "../../../infrastructure/physio/constants";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";

export {
  Card,
  Badge,
  SectionHead,
  RomBar,
  Logo,
  LogoFull,
  THEME,
  VisualizationService,
};

// Helper exports
export const initials = VisualizationService.getInitials.bind(VisualizationService);
export const romColor = VisualizationService.getRomColor.bind(VisualizationService);
export const statusMeta = {
  active: { bg: THEME.tealLight, c: THEME.tealDim, label: "Active" },
  recovered: { bg: THEME.greenLight, c: THEME.green, label: "Recovered" },
  "at-risk": { bg: THEME.redLight, c: THEME.red, label: "At Risk" },
};
