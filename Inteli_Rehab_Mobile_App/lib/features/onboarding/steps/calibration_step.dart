import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/ble/arm_band_ble_service.dart';
import '../../home/ble/arm_band_protocol.dart';
import '../baseline_recorder.dart';
import '../../../core/widgets/radial_progress.dart';
import '../onboarding_data.dart';
import '../widgets/form_widgets.dart';

enum _Phase { intro, sensors, neutral, movement, muscle, check, muscleRetry, done }

/// The guided calibration done once during sign-up. Every patient goes
/// through all of it - there is no "later" - because everything the app
/// reports afterwards is measured against it:
///
///  1. Sensors   - the band re-zeroes its gyros ('g') while the arm hangs still.
///  2. Zero pose - the current pose becomes 0 degrees ('z'), held still for a
///                 few seconds; that reading is the baseline's starting point.
///  3. Movement  - one slow bend; its furthest reach is the baseline.
///  4. Muscle    - a 3 s maximum squeeze ('m') makes muscle activation read as
///                 %MVC, then a lighter test squeeze confirms it responds.
///
/// The band measures the angle between upper arm and forearm, so this records
/// the elbow bend whichever joint was injured. The baseline is saved by the
/// onboarding flow when the patient finishes (OnboardingRepository.saveBaseline).
class CalibrationStep extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onBackToWearable;

  const CalibrationStep({super.key, required this.data, required this.onBackToWearable});

  /// Movements recorded for the baseline (also saved as sessions.reps).
  static const reps = 1; // kept short on purpose: one slow bend sets the starting range

  /// The EMG (muscle squeeze) part of calibration. Switched off for now: calibration ends after the
  /// bend. Set back to true to bring the squeeze and its check back; nothing else needs changing.
  static const includeMuscleStep = false;

  @override
  State<CalibrationStep> createState() => _CalibrationStepState();
}

class _CalibrationStepState extends State<CalibrationStep> {
  static const _sensorSeconds = 2; // firmware's gyro calibration takes ~1.2 s (300 samples x 2 sensors)
  static const _neutralSeconds = 3;
  static const _mvcSeconds = 3; // firmware's MVC window is 3000 ms (ArmEMG_IMU.ino, command 'm')
  static const _checkSeconds = 6;
  static const _checkPassPct = 30.0; // %MVC the test squeeze must reach
  static const _checkHoldSamples = 5; // ...for this many samples in a row (~160 ms)
  static const _checkReleasePct = 15.0; // the muscle must relax below this first (see _checkReleased)
  static const _reps = CalibrationStep.reps;
  static const _tick = Duration(milliseconds: 50);

  Timer? _timer;
  StreamSubscription<ArmBandSample>? _sub;
  late BaselineRecorder _recorder = BaselineRecorder(reps: _reps);
  BaselineReading? _pending; // measured, not yet confirmed by the muscle step
  DateTime? _lastSampleAt;
  double _liveAngle = 0;
  double _liveEmg = 0;
  double _checkPeak = 0;
  double _moveMin = double.infinity; // angle range seen during the movement step,
  double _moveMax = double.negativeInfinity; // to notice a band that reports no movement
  int _checkStrong = 0;

  /// The test squeeze only counts after the muscle has relaxed once. Otherwise the tail of the
  /// maximum squeeze (or a hand still tensed from it) would pass the check without proving the
  /// sensor follows the muscle.
  bool _checkReleased = false;
  bool _transitioning = false; // a band command is in flight; ignore ticks
  String? _error; // why the last attempt didn't finish
  bool _relinking = false;

  late _Phase _phase = widget.data.baseline != null ? _Phase.done : _Phase.intro;
  Duration _elapsed = Duration.zero;

  /// No samples for this long means contact with the band is lost.
  static const _stallAfter = Duration(seconds: 3);

  /// The band's gyro calibration pauses its stream for a moment.
  static const _stallAfterSensors = Duration(seconds: 6);

  /// Give up waiting for the movements after this long.
  static const _movementTimeout = Duration(seconds: 45);

  OnboardingData get data => widget.data;

  /// The band measures the elbow angle, so that is what is recorded.
  ({String instruction, String metric}) get _movement =>
      (instruction: 'Slowly bend your elbow as far as is comfortable, then straighten it.', metric: 'Elbow bend');

  @override
  void initState() {
    super.initState();
    // Live capture: an accidental rotation mustn't re-layout mid-rep (Rule 30).
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _stopCapture() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
    _transitioning = false;
  }

  void _fail(String message) {
    _stopCapture();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.intro;
      _error = message;
    });
  }

  /// Sends a calibration command; on failure ends the attempt and says why.
  Future<bool> _send(ArmBandCommand command) async {
    try {
      await data.band.sendCommand(command);
      return true;
    } catch (_) {
      _fail("Couldn't reach your band. Check it's switched on and nearby, then try again.");
      return false;
    }
  }

  void _goTo(_Phase phase) {
    if (!mounted) return;
    if (phase == _Phase.movement) {
      _moveMin = double.infinity;
      _moveMax = double.negativeInfinity;
    }
    setState(() {
      _phase = phase;
      _elapsed = Duration.zero;
    });
  }

  void _listenAndTick() {
    _sub?.cancel();
    _timer?.cancel();
    _lastSampleAt = null;
    _sub = data.band.samples.listen(_onSample);
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  Future<void> _start() async {
    _stopCapture();
    _recorder = BaselineRecorder(reps: _reps);
    _pending = null;
    setState(() {
      _error = null;
      _phase = _Phase.sensors;
      _elapsed = Duration.zero;
    });

    _listenAndTick();
    await _send(ArmBandCommand.recalibrateGyro);
  }

  void _onSample(ArmBandSample sample) {
    _lastSampleAt = DateTime.now();
    switch (_phase) {
      case _Phase.neutral:
        if (!_transitioning) _recorder.addNeutral(sample.elbowDeg);
      case _Phase.movement:
        _recorder.addMovement(sample.elbowDeg);
        if (sample.elbowDeg.isFinite) {
          _moveMin = sample.elbowDeg < _moveMin ? sample.elbowDeg : _moveMin;
          _moveMax = sample.elbowDeg > _moveMax ? sample.elbowDeg : _moveMax;
        }
      case _Phase.check:
        final pct = sample.emg1Pct.isFinite ? sample.emg1Pct : 0.0;
        _checkPeak = pct > _checkPeak ? pct : _checkPeak;
        if (pct < _checkReleasePct) _checkReleased = true;
        _checkStrong = _checkReleased && pct >= _checkPassPct ? _checkStrong + 1 : 0;
      default:
        break;
    }
    if (mounted) {
      setState(() {
        _liveAngle = sample.elbowDeg;
        _liveEmg = sample.emg1Pct.isFinite ? sample.emg1Pct.clamp(0.0, 100.0) : 0.0;
      });
    }
  }

  void _onTick() {
    if (!mounted || _transitioning) return;
    setState(() => _elapsed += _tick);

    final last = _lastSampleAt;
    final silentFor = last == null ? _elapsed : DateTime.now().difference(last);
    final limit = _phase == _Phase.sensors ? _stallAfterSensors : _stallAfter;
    if (silentFor > limit) {
      _fail('Lost contact with your band. Check it is on and nearby, then try again.');
      return;
    }

    switch (_phase) {
      case _Phase.sensors:
        if (_elapsed >= const Duration(seconds: _sensorSeconds)) unawaited(_toNeutral());
      case _Phase.neutral:
        if (_elapsed >= const Duration(seconds: _neutralSeconds)) {
          if (_recorder.neutralSamples < 10) {
            _fail("We didn't receive readings from your band. Try again.");
            return;
          }
          _goTo(_Phase.movement);
        }
      case _Phase.movement:
        if (_recorder.complete) {
          unawaited(_afterMovement());
        } else if (_elapsed >= _movementTimeout) {
          if (_recorder.repsDetected >= 1) {
            unawaited(_afterMovement()); // a shorter capture is still a usable baseline
          } else {
            _fail("We didn't detect any movement. Bend your elbow slowly as far as is comfortable, then try again.");
          }
        }
      case _Phase.muscle:
        // The squeeze window plus a beat for the band to latch its maximum.
        if (_elapsed >= const Duration(seconds: _mvcSeconds, milliseconds: 600)) {
          _checkPeak = 0;
          _checkStrong = 0;
          _checkReleased = false;
          _goTo(_Phase.check);
        }
      case _Phase.check:
        if (_checkStrong >= _checkHoldSamples) {
          _finish();
        } else if (_elapsed >= const Duration(seconds: _checkSeconds)) {
          _stopCapture();
          _goTo(_Phase.muscleRetry);
        }
      case _Phase.intro:
      case _Phase.muscleRetry:
      case _Phase.done:
        break;
    }
  }

  /// Gyros are calibrated; now make the current pose zero and hold still.
  Future<void> _toNeutral() async {
    _transitioning = true;
    if (!await _send(ArmBandCommand.setZeroPose)) return;
    await Future<void>.delayed(const Duration(milliseconds: 400)); // let the band latch the new zero
    if (!mounted) return;
    _transitioning = false;
    _goTo(_Phase.neutral);
  }

  /// Movements are in: go on to the muscle squeeze, or finish here while the EMG step is switched off.
  Future<void> _afterMovement() async {
    if (CalibrationStep.includeMuscleStep) {
      return _toMuscle();
    }
    _pending ??= _recorder.result();
    _finish();
  }

  /// Movements are in; measure the baseline, then start the muscle squeeze.
  Future<void> _toMuscle() async {
    _pending ??= _recorder.result();
    if (_pending == null) {
      _fail("We didn't detect any movement. Try again.");
      return;
    }
    _transitioning = true;
    if (!await _send(ArmBandCommand.startMvcCalibration)) return;
    if (!mounted) return;
    _transitioning = false;
    _goTo(_Phase.muscle);
  }

  /// Back to the squeeze after a missed check (restarts the band's MVC window).
  Future<void> _retryMuscle() async {
    _listenAndTick();
    await _toMuscle();
  }

  void _finish() {
    _stopCapture();
    final baseline = _pending;
    if (baseline == null) {
      _fail("We didn't detect any movement. Try again.");
      return;
    }
    data.update(() {
      data.baseline = baseline;
      // Only true once the test squeeze registered; with the EMG step off, nothing was calibrated.
      data.musclesCalibrated = CalibrationStep.includeMuscleStep;
    });
    setState(() => _phase = _Phase.done);
  }

  void _redo() {
    _stopCapture();
    data.update(() {
      data.baseline = null;
      data.baselineSaved = false; // a redo is a new baseline and has to be saved again
      data.musclesCalibrated = false;
    });
    setState(() {
      _error = null;
      _phase = _Phase.intro;
    });
  }

  Future<void> _relink() async {
    setState(() {
      _relinking = true;
      _error = null;
    });
    try {
      await data.band.connect(data.wearable!.id);
      data.update(() {}); // bandLinked changed
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            e is ArmBandException ? e.message : "Couldn't reconnect to your band. Switch it on and keep it nearby.");
      }
    }
    if (mounted) setState(() => _relinking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (data.wearable == null) return _noWearable(context);
    if (_phase != _Phase.done && _phase != _Phase.muscleRetry && !data.bandLinked && _timer == null) {
      return _notLinked(context);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_phase),
        child: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.sensors => _sensors(context),
          _Phase.neutral => _neutral(context),
          _Phase.movement => _moving(context),
          _Phase.muscle => _muscle(context),
          _Phase.check => _check(context),
          _Phase.muscleRetry => _muscleRetry(context),
          _Phase.done => _done(context),
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Takes about a minute', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'This calibrates your band and records how your ${data.sideLabel} moves today, so your '
                'physiotherapist can measure your progress from here. Every step is needed.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const _PhaseRow(
                  icon: Icons.chair_outlined,
                  title: 'Sit upright',
                  text: 'Feet flat, back supported, band on your arm.'),
              const _PhaseRow(
                  icon: Icons.pan_tool_outlined,
                  title: 'Keep still',
                  text: 'Arm hanging straight down and relaxed while the sensors calibrate.'),
              _PhaseRow(
                  icon: Icons.sync, title: _reps == 1 ? 'Move once' : 'Move $_reps times', text: _movement.instruction),
              if (CalibrationStep.includeMuscleStep)
                const _PhaseRow(
                    icon: Icons.fitness_center,
                    title: 'Squeeze your muscle',
                    text: 'Tense your biceps as hard as you can for 3 seconds, then once more, more gently.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null) ...[
          InfoBanner(icon: Icons.error_outline, tone: BannerTone.warning, text: _error!),
          const SizedBox(height: 12),
        ],
        const InfoBanner(
          icon: Icons.health_and_safety_outlined,
          tone: BannerTone.warning,
          text: 'Only move as far as feels comfortable. Stop if it hurts — a small range is still a useful baseline.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text("I'm ready — start"),
        ),
      ],
    );
  }

  Widget _countdownRing(BuildContext context, {required int totalSeconds, required Color color}) {
    final c = context.colors;
    final progress = _elapsed.inMilliseconds / (totalSeconds * 1000);
    final remaining = (totalSeconds - _elapsed.inMilliseconds / 1000).ceil().clamp(0, totalSeconds);
    return RadialProgress(
      value: progress.clamp(0.0, 1.0),
      size: 170,
      stroke: 12,
      color: color,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$remaining', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: c.ink, height: 1)),
          Text('seconds', style: TextStyle(fontSize: 12, color: c.muted)),
        ],
      ),
    );
  }

  Widget _sensors(BuildContext context) {
    return _LiveCard(
      label: 'STEP 1 OF ${CalibrationStep.includeMuscleStep ? 4 : 3}',
      title: 'Calibrating your sensors',
      text: 'Let your arm hang straight down, relaxed, and keep it completely still.',
      ring: _countdownRing(context, totalSeconds: _sensorSeconds, color: context.colors.accent),
    );
  }

  Widget _neutral(BuildContext context) {
    return _LiveCard(
      label: 'STEP 2 OF ${CalibrationStep.includeMuscleStep ? 4 : 3}',
      title: 'Hold still',
      text: 'This is your zero position. Keep your arm relaxed by your side.',
      ring: _countdownRing(context, totalSeconds: _neutralSeconds, color: context.colors.accent),
    );
  }

  /// Samples are arriving but the angle hasn't moved: the band isn't seeing
  /// the elbow bend (a sensor not reading, loose, or the band not on the arm).
  bool get _noMovementSeen =>
      _phase == _Phase.movement &&
      _elapsed >= const Duration(seconds: 8) &&
      _recorder.repsDetected == 0 &&
      _moveMax.isFinite &&
      (_moveMax - _moveMin) < 3;

  Widget _moving(BuildContext context) {
    final c = context.colors;
    final m = _movement;
    final done = _recorder.repsDetected;
    final rep = (done + 1).clamp(1, _reps);
    return _LiveCard(
      label: 'STEP 3 OF ${CalibrationStep.includeMuscleStep ? 4 : 3}',
      title: _reps == 1 ? 'Move slowly' : 'Move slowly — $rep of $_reps',
      text: m.instruction,
      ring: RadialProgress(
        value: (_liveAngle / 150).clamp(0.0, 1.0),
        size: 170,
        stroke: 12,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_liveAngle.round()}°',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: c.ink, height: 1)),
            Text(m.metric, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
      footer: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= _reps; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == rep ? 26 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i <= done || i == rep ? c.primary : c.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
          if (_noMovementSeen) ...[
            const SizedBox(height: 16),
            const InfoBanner(
              icon: Icons.sensors_off_outlined,
              tone: BannerTone.warning,
              text: "We aren't seeing your arm move. Check the band is snug on your arm with the sensors "
                  'above and below the elbow, then bend slowly. If this keeps happening, restart the band.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _muscle(BuildContext context) {
    return _LiveCard(
      label: 'STEP 4 OF 4',
      title: 'Squeeze as hard as you can',
      text: 'Tense your biceps as strongly as possible — like making a muscle — until the timer ends.',
      ring: _countdownRing(context, totalSeconds: _mvcSeconds, color: context.colors.alert),
    );
  }

  Widget _check(BuildContext context) {
    final c = context.colors;
    final reached = _checkPeak >= _checkPassPct;
    return _LiveCard(
      label: 'STEP 4 OF 4 · CHECK',
      title: 'Now squeeze about half as hard',
      text: 'We just need to see your muscle sensor respond.',
      ring: RadialProgress(
        value: (_liveEmg / 100).clamp(0.0, 1.0),
        size: 170,
        stroke: 12,
        color: reached ? c.success : c.primary,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_liveEmg.round()}%',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: c.ink, height: 1)),
            Text('muscle effort', style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _muscleRetry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.fitness_center,
          tone: BannerTone.warning,
          text: "We didn't see your muscle respond. Check the muscle sensor sits flat on the belly of your "
              'biceps, then squeeze again — hard for the 5-second count, then about half as hard.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _retryMuscle,
          icon: const Icon(Icons.replay),
          label: const Text('Try the muscle step again'),
        ),
      ],
    );
  }

  /// The band isn't linked right now (e.g. a resumed onboarding, or it
  /// dropped): calibration can't run without it.
  Widget _notLinked(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          icon: Icons.bluetooth_disabled,
          tone: BannerTone.warning,
          text: _error ?? "Your band isn't connected right now. Reconnect it to calibrate.",
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _relinking ? null : _relink,
          icon: _relinking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bluetooth_searching, size: 18),
          label: Text(_relinking ? 'Reconnecting…' : 'Reconnect my band'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: widget.onBackToWearable, child: const Text('Back to band setup')),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final c = context.colors;
    final b = data.baseline!;
    final m = _movement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: c.successTint, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: c.success, size: 32),
              ),
              const SizedBox(height: 12),
              Text('Calibration complete', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${m.metric} · ${data.sideLabel}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Metric(label: 'Starting point', value: '${b.extension}°'),
                  _Metric(label: 'Furthest', value: '${b.flexion}°'),
                  _Metric(label: 'Range', value: '${b.range}°', highlight: true),
                ],
              ),
              const SizedBox(height: 14),
              const _CheckLine(ok: true, text: 'Band sensors calibrated'),
              if (CalibrationStep.includeMuscleStep)
                _CheckLine(
                  ok: data.musclesCalibrated,
                  text: data.musclesCalibrated ? 'Muscle sensor calibrated' : 'Muscle sensor not confirmed',
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoBanner(
          icon: Icons.insights_outlined,
          text: 'Your physiotherapist will see these numbers and set targets from them.',
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
              onPressed: _redo, icon: const Icon(Icons.replay, size: 18), label: const Text('Redo calibration')),
        ),
      ],
    );
  }

  Widget _noWearable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.bluetooth_disabled,
          tone: BannerTone.warning,
          text: 'Calibration needs your Inteli Band. Pair it first.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: widget.onBackToWearable,
          icon: const Icon(Icons.bluetooth, size: 18),
          label: const Text('Pair my band'),
        ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  final bool ok;
  final String text;
  const _CheckLine({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ok ? Icons.check_circle : Icons.info_outline, size: 16, color: ok ? c.success : c.accent),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12.5, color: c.muted)),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final String label, title, text;
  final Widget ring;
  final Widget? footer;

  const _LiveCard({required this.label, required this.title, required this.text, required this.ring, this.footer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.accent)),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ring,
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _PhaseRow({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.primaryTint, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 19, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink)),
                const SizedBox(height: 1),
                Text(text, style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _Metric({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? c.primaryTint : c.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: highlight ? c.primary : c.ink)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: c.muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
