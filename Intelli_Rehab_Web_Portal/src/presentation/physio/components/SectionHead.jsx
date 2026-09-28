import { THEME } from "../../../infrastructure/physio/constants";
import useIsMobile from "../../useIsMobile";

function SectionHead({ title, sub, action }) {
  const isMobile = useIsMobile();
  return (
    <div
      style={{
        display: "flex",
        flexWrap: "wrap",
        justifyContent: "space-between",
        alignItems: isMobile ? "stretch" : "flex-start",
        gap: 16,
        marginBottom: isMobile ? 20 : 28,
      }}
    >
      <div style={{ minWidth: 0, flex: "1 1 220px" }}>
        <div style={{ fontSize: isMobile ? 22 : 28, fontWeight: 800, color: THEME.slate800, lineHeight: 1.2 }}>
          {title}
        </div>
        <div style={{ fontSize: isMobile ? 13 : 14, color: THEME.slate400, marginTop: 4 }}>
          {sub}
        </div>
      </div>
      {action && <div style={{ flex: isMobile ? "1 1 100%" : "0 0 auto", minWidth: 0 }}>{action}</div>}
    </div>
  );
}

export default SectionHead;
