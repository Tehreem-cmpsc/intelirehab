import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sensor_calibration/presentation/screens/sensor_calibration_screen.dart';
import 'live_rehab_session_screen.dart';

class PreSessionCheckScreen extends StatefulWidget {
  final String exerciseName;
  final int targetReps;
  final int targetSets;
  final double targetRom;

  const PreSessionCheckScreen({
    super.key,
    this.exerciseName = 'Elbow Flexion & Extension',
    this.targetReps = 10,
    this.targetSets = 3,
    this.targetRom = 90.0,
  });

  @override
  State<PreSessionCheckScreen> createState() => _PreSessionCheckScreenState();
}

class _PreSessionCheckScreenState extends State<PreSessionCheckScreen> {
  bool _sensorConnected = true;
  bool _sensorCalibrated = true;
  bool _emgContactOk = true;
  bool _environmentSafe = true;

  bool get _allChecksPassed =>
      _sensorConnected && _sensorCalibrated && _emgContactOk && _environmentSafe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Pre-Session Readiness'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Exercise Header Card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.navy, AppTheme.primaryTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'TARGET PROTOCOL',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '${widget.targetRom.toInt()}° ROM Goal',
                          style: const TextStyle(color: AppTheme.tealBright, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.exerciseName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.targetSets} Sets × ${widget.targetReps} Reps • Clinical Adherence Tracking',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Safety & Readiness Checklist ─────────────────────────────────
              const Text(
                'Clinical Readiness Checklist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slate800),
              ),
              const SizedBox(height: 12),

              _buildCheckItem(
                title: 'Wearable Sensor Connected',
                subtitle: 'Inteli-Arm-V2 paired via BLE (88% Battery)',
                icon: Icons.bluetooth_connected_rounded,
                value: _sensorConnected,
                onChanged: (v) => setState(() => _sensorConnected = v),
              ),
              const SizedBox(height: 10),

              _buildCheckItem(
                title: 'IMU Baseline Calibrated',
                subtitle: '0° anatomical resting reference verified',
                icon: Icons.tune_rounded,
                value: _sensorCalibrated,
                onChanged: (v) => setState(() => _sensorCalibrated = v),
                actionLabel: 'Calibrate',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SensorCalibrationScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildCheckItem(
                title: 'EMG Skin Contact Quality',
                subtitle: 'Electrodes secured with low baseline impedance',
                icon: Icons.flash_on_rounded,
                value: _emgContactOk,
                onChanged: (v) => setState(() => _emgContactOk = v),
              ),
              const SizedBox(height: 10),

              _buildCheckItem(
                title: 'Free Range-of-Motion Space',
                subtitle: 'Arm has unobstructed arc during exercise',
                icon: Icons.accessibility_rounded,
                value: _environmentSafe,
                onChanged: (v) => setState(() => _environmentSafe = v),
              ),
              const SizedBox(height: 28),

              // ── Start Action Button ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: _allChecksPassed
                      ? const LinearGradient(colors: [AppTheme.primaryTeal, AppTheme.navyMid])
                      : null,
                  color: _allChecksPassed ? null : AppTheme.slate200,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _allChecksPassed
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton.icon(
                  onPressed: _allChecksPassed
                      ? () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => LiveRehabSessionScreen(
                                exerciseName: widget.exerciseName,
                                targetReps: widget.targetReps,
                                targetSets: widget.targetSets,
                                targetRom: widget.targetRom,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 24),
                  label: const Text(
                    'Begin Rehabilitation Session',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.slate200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value ? AppTheme.greenLight : AppTheme.slate100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              value ? Icons.check_circle_rounded : icon,
              color: value ? AppTheme.green : AppTheme.slate500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slate800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            Switch.adaptive(
              value: value,
              activeTrackColor: AppTheme.primaryTeal,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
