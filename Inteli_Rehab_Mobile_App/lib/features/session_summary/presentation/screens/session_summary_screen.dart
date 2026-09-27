import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home_dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../../session_replay/presentation/screens/session_replay_screen.dart';

class SessionSummaryScreen extends StatelessWidget {
  final String exerciseName;
  final int totalReps;
  final int totalSets;
  final double peakRom;
  final double targetRom;
  final int durationSeconds;
  final int accuracyScore;

  const SessionSummaryScreen({
    super.key,
    this.exerciseName = 'Elbow Flexion & Extension',
    this.totalReps = 30,
    this.totalSets = 3,
    this.peakRom = 88.0,
    this.targetRom = 90.0,
    this.durationSeconds = 145,
    this.accuracyScore = 94,
  });

  String get _formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Completion Celebration Hero ──────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.greenLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.green.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 48),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Rehab Session Completed!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.slate800),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  exerciseName,
                  style: const TextStyle(fontSize: 14, color: AppTheme.primaryTeal, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 24),

              // ── 2x2 Biometric Metric Matrix ──────────────────────────────────
              Row(
                children: [
                  _buildMetricTile(
                    label: 'Total Reps',
                    value: '$totalReps',
                    sub: '$totalSets Sets Completed',
                    icon: Icons.repeat_rounded,
                    color: AppTheme.primaryTeal,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricTile(
                    label: 'Peak ROM',
                    value: '${peakRom.toInt()}°',
                    sub: 'Goal: ${targetRom.toInt()}°',
                    icon: Icons.rotate_right_rounded,
                    color: AppTheme.navyMid,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetricTile(
                    label: 'Form Accuracy',
                    value: '$accuracyScore%',
                    sub: 'Minimal Joint Tremor',
                    icon: Icons.verified_rounded,
                    color: AppTheme.green,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricTile(
                    label: 'Duration',
                    value: _formattedDuration,
                    sub: 'Cadence: 3.2s / rep',
                    icon: Icons.timer_outlined,
                    color: AppTheme.amber,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Muscle Fatigue Recovery Advisory ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: AppTheme.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'EMG Muscle Fatigue Assessment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.slate800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Surface EMG detected mild muscle fiber engagement with no abnormal tremor or strain exhaustion. Your bicep/tricep responded safely within clinical guidelines.',
                      style: TextStyle(fontSize: 14, color: AppTheme.slate500, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.tealSoftBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppTheme.primaryTeal),
                          SizedBox(width: 6),
                          Text(
                            'Recommended rest: 4–6 hours before next session',
                            style: TextStyle(fontSize: 14, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Cloud Sync Status ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.greenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: AppTheme.green, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Session telemetry packet synced with Dr. Tehreem\'s web portal.',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Replay & Dashboard Actions ───────────────────────────────────
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SessionReplayScreen()),
                  );
                },
                icon: const Icon(Icons.slow_motion_video_rounded),
                label: const Text('Watch Session Digital Replay'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryTeal, AppTheme.navyMid],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  label: const Text(
                    'Return to Home Dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.slate500, fontWeight: FontWeight.w600)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 14, color: AppTheme.slate500)),
          ],
        ),
      ),
    );
  }
}
