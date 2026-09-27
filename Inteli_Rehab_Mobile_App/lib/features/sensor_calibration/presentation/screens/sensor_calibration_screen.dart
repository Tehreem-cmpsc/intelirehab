import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../rehab_session/presentation/screens/pre_session_check_screen.dart';

class SensorCalibrationScreen extends StatefulWidget {
  const SensorCalibrationScreen({super.key});

  @override
  State<SensorCalibrationScreen> createState() => _SensorCalibrationScreenState();
}

class _SensorCalibrationScreenState extends State<SensorCalibrationScreen> {
  int _currentStep = 0; // 0: Strap, 1: Resting Baseline, 2: Flexion Range, 3: Completed
  bool _isCalibrating = false;
  int _countdown = 5;
  Timer? _timer;

  // Real-time simulated sensor metrics
  double _pitch = 0.0;
  double _roll = 0.0;
  final int _emgNoise = 14; // microvolts

  void _startCalibrationCountdown() {
    setState(() {
      _isCalibrating = true;
      _countdown = 5;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 1) {
          _countdown--;
          _pitch = (0.2 + (t.tick * 0.1));
          _roll = (-0.1 + (t.tick * 0.05));
        } else {
          _timer?.cancel();
          _isCalibrating = false;
          _currentStep++;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Sensor Calibration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Stepper Indicator ──────────────────────────────────────────────
              _buildStepIndicator(),
              const SizedBox(height: 24),

              // ── Active Step Card ───────────────────────────────────────────────
              _buildStepContent(),
              const SizedBox(height: 24),

              // ── Live Hardware Telemetry Monitor ────────────────────────────────
              _buildLiveTelemetryCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepPill(0, 'Placement'),
        _buildStepDivider(0),
        _buildStepPill(1, 'Neutral 0°'),
        _buildStepDivider(1),
        _buildStepPill(2, 'EMG Check'),
        _buildStepDivider(2),
        _buildStepPill(3, 'Ready'),
      ],
    );
  }

  Widget _buildStepPill(int step, String title) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppTheme.green
                  : isCurrent
                      ? AppTheme.primaryTeal
                      : Colors.white,
              border: Border.all(
                color: isDone
                    ? AppTheme.green
                    : isCurrent
                        ? AppTheme.primaryTeal
                        : AppTheme.slate200,
                width: 2,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : AppTheme.slate500,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? AppTheme.primaryTealDark : AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final passed = _currentStep > step;
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: passed ? AppTheme.green : AppTheme.slate200,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepCard(
          icon: Icons.accessibility_new_rounded,
          title: 'Step 1: Strap Placement',
          subtitle:
              'Position the Inteli-Wearable strap snug on your upper forearm, 2 inches below the elbow crease. The sensor arrow should point towards your wrist.',
          child: Column(
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.tealSoftBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/human_hand.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Sensor in Place — Next Step'),
              ),
            ],
          ),
        );

      case 1:
        return _buildStepCard(
          icon: Icons.straighten_rounded,
          title: 'Step 2: Neutral 0° Baseline',
          subtitle:
              'Rest your arm relaxed straight down by your side. Keep still during the 5-second calibration to lock the 0° anatomical position.',
          child: Column(
            children: [
              if (_isCalibrating) ...[
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (5 - _countdown) / 5.0,
                        strokeWidth: 6,
                        color: AppTheme.primaryTeal,
                        backgroundColor: AppTheme.tealLight,
                      ),
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Holding zero baseline… keep arm relaxed.',
                  style: TextStyle(fontSize: 14, color: AppTheme.slate500),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startCalibrationCountdown,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Start 5s Baseline Capture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ],
          ),
        );

      case 2:
        return _buildStepCard(
          icon: Icons.electric_bolt_rounded,
          title: 'Step 3: EMG Bio-Potential Check',
          subtitle:
              'Now lightly squeeze your fist and release. This measures muscle skin contact impedance to verify electrode conductance.',
          child: Column(
            children: [
              if (_isCalibrating) ...[
                LinearProgressIndicator(
                  value: (5 - _countdown) / 5.0,
                  backgroundColor: AppTheme.tealLight,
                  color: AppTheme.primaryTeal,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sampling EMG resting noise: $_emgNoise µV (Optimal)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.green),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _startCalibrationCountdown,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('Verify Muscle Sensor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ],
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.green.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Calibration Complete!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.slate800),
              ),
              const SizedBox(height: 6),
              const Text(
                'IMU zero-baseline locked and EMG surface conductance is within clinical tolerance.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.slate500, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PreSessionCheckScreen(
                        exerciseName: 'Elbow Flexion & Extension',
                        targetReps: 10,
                        targetSets: 3,
                        targetRom: 90.0,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Proceed to Session Check'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildStepCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryTeal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.slate800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Guided Calibration Protocol',
                      style: TextStyle(fontSize: 14, color: AppTheme.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 15, color: AppTheme.slate600, height: 1.45),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLiveTelemetryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sensors_rounded, color: AppTheme.primaryTeal, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Live Sensor Telemetry Stream',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.greenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '50 Hz Active',
                  style: TextStyle(fontSize: 14, color: AppTheme.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTelemetryField('Pitch (Angle)', '${_pitch.toStringAsFixed(1)}°'),
              _buildTelemetryField('Roll', '${_roll.toStringAsFixed(1)}°'),
              _buildTelemetryField('EMG Noise', '$_emgNoise µV'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.slate500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.navy),
          ),
        ],
      ),
    );
  }
}
