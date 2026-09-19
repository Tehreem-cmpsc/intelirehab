export class Patient {
  constructor({
    id,
    name,
    regId,
    injury,
    rom,
    trend,
    streak,
    status,
    wearable,
    approved,
    warning,
    sessions,
    currentExercise,
    emg,
    romWeekly,
  }) {
    this.id = id;
    this.name = name;
    this.regId = regId;
    this.injury = injury;
    this.rom = rom;
    this.trend = trend;
    this.streak = streak;
    this.status = status; // 'active', 'recovered', 'at-risk'
    this.wearable = wearable;
    this.approved = approved;
    this.warning = warning;
    this.sessions = sessions || [];
    this.currentExercise = currentExercise;
    this.emg = emg || [];
    this.romWeekly = romWeekly || [];
  }

  isAtRisk() {
    return this.status === "at-risk";
  }

  isPendingApproval() {
    return !this.approved;
  }

  getStatusLabel() {
    const statusMap = {
      active: "Active",
      recovered: "Recovered",
      "at-risk": "At Risk",
    };
    return statusMap[this.status] || "Unknown";
  }
}
