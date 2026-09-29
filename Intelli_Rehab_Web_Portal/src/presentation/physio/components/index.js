import Card from "./Card";
import Badge from "./Badge";
import SectionHead from "./SectionHead";
import RomBar from "./RomBar";
import Logo from "./Logo";
import LogoFull from "./LogoFull";
import PatientDetails, { chosenPhysioLabel } from "./PatientDetails";
import { THEME } from "../../../infrastructure/physio/constants";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";

export {
  Card,
  Badge,
  SectionHead,
  RomBar,
  Logo,
  LogoFull,
  PatientDetails,
  chosenPhysioLabel,
  THEME,
  VisualizationService,
};

// Helper exports
export const initials = VisualizationService.getInitials.bind(VisualizationService);
export const romColor = VisualizationService.getRomColor.bind(VisualizationService);
// Same getters as STATUS_META so the colours follow the current theme.
export { STATUS_META as statusMeta } from "../../../infrastructure/physio/constants";
