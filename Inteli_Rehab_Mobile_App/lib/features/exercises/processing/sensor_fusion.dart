import 'package:flutter/animation.dart';

/// Intelligence & Processing Layer — Sensor Fusion (SDD §3.1.3).
///
/// On real hardware this combines the wearable's two IMUs (upper arm +
/// forearm, streamed over BLE by the Communication Layer) into a single
/// joint angle, the same job firmware/lib/ArmEMG_IMU/MadgwickAHRS.cpp does on-device
/// for orientation. There's no BLE plugin yet (see WearableConnectionController),
/// so [angleAtPhase] stands in for that fusion step: it turns "how far
/// through this rep" into the joint angle a real fusion pipeline would
/// output, using the same easing curve a natural raise-and-lower motion
/// follows. Kept as its own class (rather than inlined in SessionSimulator)
/// so the Processing Layer boundary is real in the code, not just in the
/// diagram — this is what a native fusion implementation would replace.
class SensorFusion {
  const SensorFusion();

  /// [repPhase] is 0..1 through one rep (up and back down); [targetAngle]
  /// is the peak angle a full rep reaches. Returns the fused joint angle
  /// for this instant.
  int angleAtPhase(double repPhase, int targetAngle) {
    final eased = Curves.easeInOut.transform(repPhase.clamp(0.0, 1.0));
    return (targetAngle * eased).round();
  }

  /// Where in the up-then-down rep [elapsed] sits, as a 0..1 phase — 0 at
  /// the start and the end, 1 at the peak.
  double phaseOf(Duration elapsed, Duration repDuration) {
    final halfway = repDuration ~/ 2;
    final t = elapsed >= halfway
        ? 1 - (elapsed - halfway).inMilliseconds / halfway.inMilliseconds
        : elapsed.inMilliseconds / halfway.inMilliseconds;
    return t.clamp(0.0, 1.0);
  }
}
