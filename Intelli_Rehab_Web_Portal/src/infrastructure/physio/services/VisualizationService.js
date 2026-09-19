import { THEME } from "../constants";

class VisualizationService {
  getRomColor(value) {
    if (value >= 80) return THEME.green;
    if (value >= 55) return THEME.teal;
    if (value >= 35) return THEME.amber;
    return THEME.red;
  }

  getStatusMeta(status) {
    const statusMap = {
      active: {
        bg: THEME.tealLight,
        c: THEME.tealDim,
        label: "Active",
      },
      recovered: {
        bg: THEME.greenLight,
        c: THEME.green,
        label: "Recovered",
      },
      "at-risk": {
        bg: THEME.redLight,
        c: THEME.red,
        label: "At Risk",
      },
    };
    return statusMap[status] || statusMap.active;
  }

  getDifficultyColor(difficulty) {
    const colorMap = {
      Beginner: THEME.green,
      Intermediate: THEME.amber,
      Advanced: THEME.red,
    };
    return colorMap[difficulty] || THEME.slate500;
  }

  getDifficultyBg(difficulty) {
    const bgMap = {
      Beginner: THEME.greenLight,
      Intermediate: THEME.amberLight,
      Advanced: THEME.redLight,
    };
    return bgMap[difficulty] || THEME.slate100;
  }

  getInitials(name) {
    return name
      .split(" ")
      .map((w) => w[0])
      .join("");
  }
}

export default new VisualizationService();
