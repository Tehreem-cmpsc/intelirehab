abstract class RehabSessionState {
  const RehabSessionState();
}

class RehabSessionInitial extends RehabSessionState {
  const RehabSessionInitial();
}

class RehabSessionActive extends RehabSessionState {
  final int reps;
  final double currentAngle;
  final bool fatigueWarning;

  const RehabSessionActive({
    required this.reps,
    required this.currentAngle,
    required this.fatigueWarning,
  });
}

class RehabSessionCompleted extends RehabSessionState {
  const RehabSessionCompleted();
}
