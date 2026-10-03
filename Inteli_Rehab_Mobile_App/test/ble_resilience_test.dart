// The pieces of the BLE link that can be pinned down without hardware:
// reconnect timing, and turning the band's angle stream into the baseline.
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/reconnect_backoff.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/baseline_recorder.dart';

void main() {
  group('ReconnectBackoff', () {
    test('starts quick, eases off, then gives up', () {
      final b = ReconnectBackoff();
      final waits = <Duration>[];
      for (var d = b.next(); d != null; d = b.next()) {
        waits.add(d);
      }
      expect(waits, ReconnectBackoff.delays);
      expect(waits.first, lessThan(waits.last));
      expect(b.next(), isNull, reason: 'stays given up');
    });

    test('reset starts over', () {
      final b = ReconnectBackoff();
      while (b.next() != null) {}
      b.reset();
      expect(b.next(), ReconnectBackoff.delays.first);
    });

    test('stop gives up immediately', () {
      final b = ReconnectBackoff()..next();
      b.stop();
      expect(b.next(), isNull);
    });
  });

  group('BaselineRecorder', () {
    BaselineRecorder neutralAt(double angle, {int reps = 3}) {
      final r = BaselineRecorder(reps: reps);
      for (var i = 0; i < 40; i++) {
        r.addNeutral(angle);
      }
      return r;
    }

    void lift(BaselineRecorder r, double peak) {
      for (final a in [3.0, peak * 0.3, peak * 0.7, peak, peak * 0.7, peak * 0.3, 4.0]) {
        r.addMovement(a);
      }
    }

    test('records the starting point and the typical furthest reach', () {
      final r = neutralAt(2);
      lift(r, 100);
      lift(r, 110);
      lift(r, 105);
      expect(r.complete, isTrue);
      final b = r.result()!;
      expect(b.neutral, 2);
      expect(b.flexion, 105, reason: 'median of 100/110/105');
      expect(b.extension, 2);
      expect(b.range, 103);
    });

    test('one wild rep does not skew the result', () {
      final r = neutralAt(0);
      lift(r, 100);
      lift(r, 100);
      lift(r, 170);
      expect(r.result()!.flexion, 100);
    });

    test('small wobbles are not movements', () {
      final r = neutralAt(0);
      for (var i = 0; i < 5; i++) {
        lift(r, 18); // never clears the 25 degree minimum
      }
      expect(r.repsDetected, 0);
      expect(r.result(), isNull);
    });

    test('works whatever the zero pose was (thresholds are relative to neutral)', () {
      final r = neutralAt(30);
      for (var i = 0; i < 3; i++) {
        lift(r, 30 + 100);
      }
      // The helper's low samples (3, ...) sit below this neutral, so only the
      // large lifts count as movements.
      expect(r.result()!.flexion, 130);
    });

    test('ignores NaN and no data yet', () {
      final r = BaselineRecorder();
      r.addNeutral(double.nan);
      r.addMovement(double.infinity);
      expect(r.neutralSamples, 0);
      expect(r.result(), isNull);
    });

    test('partial capture still gives a usable baseline', () {
      final r = neutralAt(0);
      lift(r, 90);
      expect(r.complete, isFalse);
      expect(r.result()!.flexion, 90);
    });
  });
}
