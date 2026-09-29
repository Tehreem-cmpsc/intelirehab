// Unit tests for the Intelligence & Processing Layer (SDD §3.1.3) —
// SensorFusion, EmgProcessor and AiEngine — now that SessionSimulator
// composes them instead of doing the same work inline. Testing them here
// on their own is the practical payoff of splitting the layer out.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/ai_engine.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/emg_processor.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/sensor_fusion.dart';

void main() {
  group('SensorFusion', () {
    const fusion = SensorFusion();

    test('phase runs 0 -> 1 -> 0 across a rep (up then down)', () {
      const repDuration = Duration(milliseconds: 2800);
      final start = fusion.phaseOf(Duration.zero, repDuration);
      final peak = fusion.phaseOf(repDuration ~/ 2, repDuration);
      final end = fusion.phaseOf(repDuration, repDuration);
      expect(start, 0);
      expect(peak, 1);
      expect(end, 0);
    });

    test('angle scales with phase toward the target', () {
      expect(fusion.angleAtPhase(0, 80), 0);
      expect(fusion.angleAtPhase(1, 80), 80);
      expect(fusion.angleAtPhase(0.5, 80), greaterThan(0));
      expect(fusion.angleAtPhase(0.5, 80), lessThan(80));
    });
  });

  group('EmgProcessor', () {
    const emg = EmgProcessor();

    test('activation rises from resting to high across the phase', () {
      expect(emg.activationAtPhase(0), MuscleActivation.resting);
      expect(emg.activationAtPhase(0.3), MuscleActivation.light);
      expect(emg.activationAtPhase(0.6), MuscleActivation.moderate);
      expect(emg.activationAtPhase(0.95), MuscleActivation.high);
    });

    test('fatigue increment is always positive and bounded', () {
      final random = math.Random(7);
      for (var i = 0; i < 20; i++) {
        final inc = emg.fatigueIncrement(random);
        expect(inc, greaterThanOrEqualTo(0.04));
        expect(inc, lessThanOrEqualTo(0.09));
      }
    });

    test('levelOf matches the documented thresholds', () {
      expect(EmgProcessor.levelOf(0), FatigueLevel.normal);
      expect(EmgProcessor.levelOf(0.35), FatigueLevel.mild);
      expect(EmgProcessor.levelOf(0.65), FatigueLevel.moderate);
      expect(EmgProcessor.levelOf(0.9), FatigueLevel.critical);
    });
  });

  group('AiEngine', () {
    const ai = AiEngine();

    test('a normal-tier assessment carries no alert', () {
      // roll < 0.72 with this seed's first draw stays "normal".
      final assessment = ai.assessRep(math.Random(42));
      if (assessment.tier == SafetyTier.normal) {
        expect(assessment.alert, isNull);
      } else {
        expect(assessment.alert, isNotNull);
        expect(assessment.alert!.tier, assessment.tier);
      }
    });

    test('every non-normal tier produces a factually worded alert', () {
      for (var seed = 0; seed < 200; seed++) {
        final assessment = ai.assessRep(math.Random(seed));
        if (assessment.tier == SafetyTier.normal) continue;
        expect(assessment.alert, isNotNull);
        expect(assessment.alert!.message, isNot(contains('mistake')));
        expect(assessment.alert!.message, isNot(contains('wrong')));
      }
    });

    test('produces both needsCorrection and unsafe tiers across enough rolls', () {
      final tiers = {for (var s = 0; s < 300; s++) ai.assessRep(math.Random(s)).tier};
      expect(tiers, contains(SafetyTier.needsCorrection));
      expect(tiers, contains(SafetyTier.unsafe));
      expect(tiers, contains(SafetyTier.normal));
    });
  });
}
