import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/entities/patient_entity.dart';
import '../../../auth/data/datasources/auth_remote_data_source.dart';
import '../../../patient_feedback/presentation/screens/patient_feedback_screen.dart';
import '../../../sensor_calibration/presentation/screens/sensor_calibration_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final PatientEntity? patient;
  final bool isEmbedded;

  const ProfileSettingsScreen({super.key, this.patient, this.isEmbedded = false});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _authService = AuthService();

  bool _voiceFeedbackEnabled = true;
  bool _hapticVibrationEnabled = true;
  bool _wifiOnlySync = false;

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Inteli-Rehab?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.slate600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient ??
        const PatientEntity(
          id: 'AYUB-P-104',
          name: 'Ayesha Khan',
          email: 'ayesha.k@intelirehab.com',
          injury: 'Rotator Cuff Tear & Elbow Stiffness',
        );

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Patient Profile & Settings'),
        automaticallyImplyLeading: !widget.isEmbedded,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Patient Info Card ──────────────────────────────────────────────
            _buildPatientHeader(p),
            const SizedBox(height: 20),

            // ── My Clinic & Care Team Card ─────────────────────────────────────
            _buildCareTeamCard(p),
            const SizedBox(height: 20),

            // ── Wearable Device & Calibration Card ─────────────────────────────
            _buildHardwareCard(),
            const SizedBox(height: 20),

            // ── Clinical App Preferences ───────────────────────────────────────
            _buildPreferencesCard(),
            const SizedBox(height: 20),

            // ── Patient Community Feedback ─────────────────────────────────────
            _buildFeedbackNavigationCard(),
            const SizedBox(height: 20),

            // ── Sign Out Button ────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout_rounded, color: AppTheme.red),
              label: const Text(
                'Sign Out from Device',
                style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.red, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Inteli-Rehab Mobile App v1.0.0\nAyub Medical Complex Clinical Rehabilitation System',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeader(PatientEntity p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryTeal, AppTheme.navyMid],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'AK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slate800),
                ),
                const SizedBox(height: 2),
                Text(
                  p.email,
                  style: const TextStyle(fontSize: 14, color: AppTheme.slate500),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.greenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Reg ID: ${p.id} • Approved',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTeamCard(PatientEntity p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 20),
              SizedBox(width: 8),
              Text(
                'My Clinic & Care Team',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Associated Clinic', 'Ayub Medical Complex (Rehab Dept)'),
          const Divider(height: 16, color: AppTheme.slate100),
          _buildInfoRow('Assigned Doctor', 'Dr. Tehreem (Physiotherapist • DRID001)'),
          const Divider(height: 16, color: AppTheme.slate100),
          _buildInfoRow('Diagnosis', p.injury ?? 'Post-Op Joint Adhesion Rehabilitation'),
          const Divider(height: 16, color: AppTheme.slate100),
          _buildInfoRow('Prescription Phase', 'Active Phase 2 (Joint Range Expansion)'),
        ],
      ),
    );
  }

  Widget _buildHardwareCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                  Icon(Icons.developer_board_rounded, color: AppTheme.primaryTeal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Wearable Sensor Hardware',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.greenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Paired', style: TextStyle(color: AppTheme.green, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Hardware Model', 'Inteli-Wearable Arm V2 (ESP32-IMU)'),
          const Divider(height: 16, color: AppTheme.slate100),
          _buildInfoRow('Firmware Version', 'v1.4.2 (Latest)'),
          const Divider(height: 16, color: AppTheme.slate100),
          _buildInfoRow('Battery Level', '88% • Normal Consumption'),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SensorCalibrationScreen()),
              );
            },
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Recalibrate Sensors'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: AppTheme.tealLight,
              foregroundColor: AppTheme.primaryTealDark,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rehabilitation Preferences',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Real-Time Voice Coaching', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('Voice guidance chimes at target ROM angle', style: TextStyle(fontSize: 14)),
            value: _voiceFeedbackEnabled,
            activeTrackColor: AppTheme.primaryTeal,
            onChanged: (v) => setState(() => _voiceFeedbackEnabled = v),
          ),
          const Divider(height: 12, color: AppTheme.slate100),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptic Vibration Alerts', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('Vibrate sensor on muscle fatigue warning', style: TextStyle(fontSize: 14)),
            value: _hapticVibrationEnabled,
            activeTrackColor: AppTheme.primaryTeal,
            onChanged: (v) => setState(() => _hapticVibrationEnabled = v),
          ),
          const Divider(height: 12, color: AppTheme.slate100),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wi-Fi Only Sync', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('Sync telemetry data only on Wi-Fi connection', style: TextStyle(fontSize: 14)),
            value: _wifiOnlySync,
            activeTrackColor: AppTheme.primaryTeal,
            onChanged: (v) => setState(() => _wifiOnlySync = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackNavigationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.tealSoftBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.reviews_outlined, color: AppTheme.primaryTeal, size: 22),
        ),
        title: const Text(
          'Patient Community Feedback',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
        ),
        subtitle: const Text(
          'Read verified recovery experiences and progress',
          style: TextStyle(fontSize: 14, color: AppTheme.slate500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.slate400),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PatientFeedbackScreen()),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.slate500)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slate800),
        ),
      ],
    );
  }
}
