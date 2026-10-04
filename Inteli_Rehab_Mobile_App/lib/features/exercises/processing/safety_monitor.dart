/// The red, "stop now" rule check. It looks at every sample as it arrives - not after the rep -
/// because the model-based amber check only speaks about half a second after the arm comes back down,
/// so it cannot stop a movement as it happens.
///
/// Two rules, each of which must hold for a short window so one noisy sample cannot stop a session:
///   * the elbow angle is above [SafetyLimits.maxAngleDeg];
///   * the angular speed is above [SafetyLimits.maxSpeedDegPerSec].
///
/// THE LIMITS ARE PLACEHOLDERS. They are the values this app used before, not clinical limits. The
/// training data cannot set them (healthy peaks reach about 150 degrees and the fastest healthy reps
/// about 750 deg/s, while Kinect noise spikes go much higher). A physiotherapist should set them,
/// probably per patient.
class SafetyLimits {
  final double maxAngleDeg;
  final double maxSpeedDegPerSec;

  /// How long a limit must be exceeded before it counts.
  final Duration hold;

  const SafetyLimits({
    required this.maxAngleDeg,
    this.maxSpeedDegPerSec = 300,
    this.hold = const Duration(milliseconds: 100),
  });
}

enum SafetyViolation { angle, speed }

class SafetyMonitor {
  final SafetyLimits limits;
  DateTime? _angleSince;
  DateTime? _speedSince;

  SafetyMonitor(this.limits);

  /// Feed every sample. Returns the rule that has now been broken for the whole hold window, or null.
  SafetyViolation? update({required double angle, required double speed, required DateTime now}) {
    _angleSince = angle > limits.maxAngleDeg ? (_angleSince ?? now) : null;
    _speedSince = speed > limits.maxSpeedDegPerSec ? (_speedSince ?? now) : null;

    if (_angleSince != null && now.difference(_angleSince!) >= limits.hold) return SafetyViolation.angle;
    if (_speedSince != null && now.difference(_speedSince!) >= limits.hold) return SafetyViolation.speed;
    return null;
  }

  /// Forget what was seen (after a stop, a pause, or the start of a fresh rep).
  void reset() {
    _angleSince = null;
    _speedSince = null;
  }
}
