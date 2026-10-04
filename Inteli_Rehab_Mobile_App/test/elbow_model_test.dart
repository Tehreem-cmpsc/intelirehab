// The Dart copy of the trained elbow model must give the same numbers as the real PyTorch model.
// test/fixtures/elbow_golden.json is produced by Inteli_Rehab_AI_Pipeline/src/elbow/make_golden_vectors.py
// (reps with the score and rebuilt curve PyTorch computes). If you retrain or recalibrate, re-run
// export_to_app.py and make_golden_vectors.py together.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/elbow_autoencoder.dart';

ElbowAutoencoder _model() => ElbowAutoencoder.fromJson(File('assets/ai/elbow_autoencoder.json').readAsStringSync());

void main() {
  final golden = jsonDecode(File('test/fixtures/elbow_golden.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (golden['cases'] as List).cast<Map<String, dynamic>>();

  group('ElbowAutoencoder matches PyTorch', () {
    final model = _model();

    for (final c in cases) {
      test(c['name'] as String, () {
        final angle = [for (final v in c['angle'] as List) (v as num).toDouble()];
        final result = model.score(angle, (c['duration_s'] as num).toDouble());

        final expected = (c['score'] as num).toDouble();
        expect(result.score, closeTo(expected, expected * 1e-3 + 1e-6), reason: 'score');

        final rebuilt = [for (final v in c['rebuilt_deg'] as List) (v as num).toDouble()];
        expect(result.rebuiltDegrees.length, 100);
        var worst = 0.0;
        for (var i = 0; i < 100; i++) {
          worst = worst > (result.rebuiltDegrees[i] - rebuilt[i]).abs() ? worst : (result.rebuiltDegrees[i] - rebuilt[i]).abs();
        }
        expect(worst, lessThan(0.05), reason: 'rebuilt curve differs from PyTorch by up to $worst degrees');
      });
    }

    test('the thresholds in the file are the ones the notebook saved', () {
      expect(model.thresholdGentle, closeTo((golden['threshold_gentle'] as num).toDouble(), 1e-9));
      expect(model.thresholdBalanced, lessThan(model.thresholdGentle));
      expect(model.tolerance.length, 100);
      expect(model.healthyDuration.$1, closeTo(0.76, 0.01));
      expect(model.healthyDuration.$2, closeTo(4.19, 0.01));
    });
  });

  group('ElbowAutoencoder input checks', () {
    final model = _model();
    test('a rep must have exactly 100 points', () {
      expect(() => model.score(List.filled(99, 10), 2), throwsArgumentError);
    });
    test('the duration must be a positive number', () {
      expect(() => model.score(List.filled(100, 10), 0), throwsArgumentError);
      expect(() => model.score(List.filled(100, 10), double.nan), throwsArgumentError);
    });
    test('a damaged model file is refused, not run', () {
      expect(() => ElbowAutoencoder.fromJson('not json'), throwsFormatException);
      expect(() => ElbowAutoencoder.fromJson('{"format":2}'), throwsFormatException);
    });
  });
}
