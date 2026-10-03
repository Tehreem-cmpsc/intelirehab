import '../../../core/util/uuid.dart';
import '../exercises_models.dart';
import 'ai_engine.dart';

/// What one completed rep looked like, measured from the band's stream.
class RepMetrics {
  final double peakDegrees;
  final double targetDegrees;
  final double peakSpeedDegPerSec;
  final Duration duration;
  const RepMetrics({
    required this.peakDegrees,
    required this.targetDegrees,
    required this.peakSpeedDegPerSec,
    required this.duration,
  });

  /// 1.0 = the rep reached exactly the target angle.
  double get reach => targetDegrees <= 0 ? 1 : peakDegrees / targetDegrees;
}

/// Rule-based safety/form call for one rep, from real joint-angle data.
///
/// This is a transparent stand-in for the trained model (the AI Training
/// Pipeline, SDD §3.1.8) - fixed thresholds a clinician can read and adjust,
/// not a learned classifier. The thresholds are reasonable starting points,
/// NOT clinically validated: have a physiotherapist review them before
/// patients rely on them. Replacing this class is the swap-in point for the
/// real model; nothing else needs to change.
class RepAssessor {
  /// Peak angular speed above which a rep is jerky enough to stop for.
  static const unsafeSpeedDegPerSec = 300.0;

  /// Above this (but below unsafe) the movement should be slower.
  static const fastSpeedDegPerSec = 150.0;

  /// A rep faster than this end to end is rushed.
  static const minRepDuration = Duration(milliseconds: 1200);

  /// Reaching less than this fraction of the target angle is "short".
  static const shortReach = 0.8;

  const RepAssessor();

  RepAssessment assess(RepMetrics m, DateTime now) {
    if (m.peakSpeedDegPerSec > unsafeSpeedDegPerSec) {
      return _result(SafetyTier.unsafe, 'Potentially unsafe movement - pause and reset your form.', now);
    }
    if (m.peakSpeedDegPerSec > fastSpeedDegPerSec || m.duration < minRepDuration) {
      return _result(SafetyTier.needsCorrection, 'Slow down - move smoothly through the rep.', now);
    }
    if (m.reach < shortReach) {
      return _result(SafetyTier.needsCorrection, 'Try to reach a little further.', now);
    }
    return const RepAssessment(tier: SafetyTier.normal, alert: null);
  }

  RepAssessment _result(SafetyTier tier, String message, DateTime now) => RepAssessment(
        tier: tier,
        alert: SessionAlert(id: uuidV4(), tier: tier, message: message, at: now),
      );
}
