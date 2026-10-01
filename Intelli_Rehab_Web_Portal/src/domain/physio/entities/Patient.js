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
    emg,
    romWeekly,
    profile,
    injuryDetails,
    device,
    baseline,
    noRecentSessions,
    wearableLive,
    wearableLastSeen,
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
    this.emg = emg || [];
    this.romWeekly = romWeekly || [];
    // Onboarding answers from the mobile app (see PatientUseCases.toPatient).
    this.profile = profile || {};
    this.injuryDetails = injuryDetails || null;
    this.device = device || null;
    this.baseline = baseline || null;
    // True when there are no exercise sessions in the loaded window, so ROM /
    // trend / streak of 0 mean "no recent data", not "zero progress".
    this.noRecentSessions = Boolean(noRecentSessions);
    // `wearable` means "a band has been paired"; these say whether it is
    // connected right now (WearablePresenceUseCases), merged in by App.
    this.wearableLive = Boolean(wearableLive);
    this.wearableLastSeen = wearableLastSeen || null;
  }

  // Copy with some fields changed, keeping the class (and its methods).
  // `{ ...patient }` would silently drop isAtRisk() etc.
  with(changes) {
    return Object.assign(Object.create(Object.getPrototypeOf(this)), this, changes);
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
