import { THEME } from "../../../infrastructure/physio/constants";
import VisualizationService from "../../../infrastructure/physio/services/VisualizationService";

function RomBar({ value, height = 6 }) {
  const color = VisualizationService.getRomColor(value);
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
      }}
    >
      <div
        style={{
          flex: 1,
          height,
          background: THEME.slate100,
          borderRadius: 99,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            // ROM can exceed 100% of target; the label shows the real value.
            width: `${Math.max(0, Math.min(100, value))}%`,
            height: "100%",
            background: color,
            borderRadius: 99,
          }}
        />
      </div>
      <span
        style={{
          fontSize: 12,
          fontWeight: 700,
          color,
          minWidth: 35,
        }}
      >
        {value}%
      </span>
    </div>
  );
}

export default RomBar;
