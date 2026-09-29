import 'dart:math' as math;

import '../../../core/util/uuid.dart';
import '../exercises_models.dart';

/// One rep's inference: the movement-error/safety-tier call the AI Engine
/// makes, and the alert it produces when the rep isn't clean (feeds both
/// the Digital Twin's colour-coding and the alerts list — SDD §3.1.9,
/// "AI results → Live 3D model + alerts").
class RepAssessment {
  final SafetyTier tier;
  final SessionAlert? alert;
  const RepAssessment({required this.tier, required this.alert});
}

/// Intelligence & Processing Layer — AI Engine (SDD §3.1.3).
///
/// Detects movement errors and fatigue trends from the fused sensor
/// stream. The real model (trained offline by the AI Training Pipeline —
/// Inteli_Rehab_AI_Pipeline — and exported to the app per SDD §3.1.8)
/// isn't wired up yet, so [assessRep] stands in for it: a per-rep call
/// that decides the safety tier a real classifier would output from the
/// joint-angle/EMG stream. Isolated here so swapping in the trained model
/// later means replacing this one class, not hunting through the session
/// orchestrator.
class AiEngine {
  const AiEngine();

  RepAssessment assessRep(math.Random random) {
    final roll = random.nextDouble();
    final tier = roll > 0.93
        ? SafetyTier.unsafe
        : roll > 0.72
            ? SafetyTier.needsCorrection
            : SafetyTier.normal;

    if (tier == SafetyTier.normal) return RepAssessment(tier: tier, alert: null);
    return RepAssessment(
      tier: tier,
      alert: SessionAlert(
        id: uuidV4(),
        tier: tier,
        message: tier == SafetyTier.unsafe
            ? 'Potentially unsafe movement — pause and reset your form.'
            : 'Needs correction — lower your arm.',
        at: DateTime.now(),
      ),
    );
  }
}
