import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/entities/patient_entity.dart';
import '../../../exercise_plan/presentation/screens/exercise_plan_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile_settings/presentation/screens/profile_settings_screen.dart';
import '../../../progress/presentation/screens/progress_screen.dart';
import '../../../rehab_session/presentation/screens/pre_session_check_screen.dart';
import '../../../sensor_calibration/presentation/screens/sensor_calibration_screen.dart';
import '../../../session_replay/presentation/screens/session_replay_screen.dart';
import '../../../wearable_connection/presentation/screens/wearable_connection_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final PatientEntity? patient;

  const HomeDashboardScreen({super.key, this.patient});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _currentIndex = 0;

  late final PatientEntity _currentPatient;

  // Mock patient state
  final bool _isSensorConnected = true;
  final int _sensorBattery = 88;
  final int _streakDays = 5;
  final double _currentRom = 74.0;
  final double _targetRom = 90.0;

  @override
  void initState() {
    super.initState();
    _currentPatient = widget.patient ??
        const PatientEntity(
          id: 'PAT-2026-081',
          name: 'Ayesha Khan',
          email: 'ayesha.k@intelirehab.com',
          clinicId: 'AYUB-MED-01',
          physiotherapistId: 'DRID001',
          injury: 'Rotator Cuff Tear & Elbow Stiffness',
          affectedJoint: 'Right Arm / Elbow',
          recoveryPercentage: 78.0,
          streakDays: 5,
        );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Top-level tabs
    final List<Widget> pages = [
      _buildHomeOverview(),
      const ExercisePlanScreen(isEmbedded: true),
      const WearableConnectionScreen(isEmbedded: true),
      const ProgressScreen(isEmbedded: true),
      ProfileSettingsScreen(patient: _currentPatient, isEmbedded: true),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.slate200, width: 1.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.navy.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryTeal,
          unselectedItemColor: AppTheme.slate500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center_rounded),
              label: 'Exercises',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_searching_rounded),
              activeIcon: Icon(Icons.bluetooth_connected_rounded),
              label: 'Device',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_rounded),
              activeIcon: Icon(Icons.analytics_rounded),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 0: Home Overview ───────────────────────────────────────────────────
  Widget _buildHomeOverview() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header ───────────────────────────────────────────────────────
          _buildHeader(),
          const SizedBox(height: 16),

          // ── Wearable Status Banner ───────────────────────────────────────────
          _buildSensorStatusBanner(),
          const SizedBox(height: 16),

          // ── Prescribed Care Team & Clinic Card ───────────────────────────────
          _buildCareTeamCard(),
          const SizedBox(height: 18),

          // ── Today's Hero Rehab Session Card ──────────────────────────────────
          _buildTodayRehabHeroCard(),
          const SizedBox(height: 20),

          // ── Daily Metric Ring & Biofeedback Summary ──────────────────────────
          _buildMetricsSection(),
          const SizedBox(height: 22),

          // ── Quick Action Shortcuts ───────────────────────────────────────────
          _buildQuickActions(),
          const SizedBox(height: 22),

          // ── Recent Sessions Replay Feed ──────────────────────────────────────
          _buildRecentSessionsFeed(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryTeal, AppTheme.navyMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navy.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'AK',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${_currentPatient.name.split(' ').first} 👋',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slate800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Rehab Program Day 24',
                      style: TextStyle(fontSize: 14, color: AppTheme.slate500, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: const Icon(Icons.notifications_none_rounded, color: AppTheme.slate800, size: 22),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorStatusBanner() {
    return InkWell(
      onTap: () => _onTabTapped(2), // switch to Device tab
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isSensorConnected ? AppTheme.tealLight : AppTheme.amberLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSensorConnected
                ? AppTheme.primaryTeal.withValues(alpha: 0.25)
                : AppTheme.amber.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _isSensorConnected ? AppTheme.primaryTeal : AppTheme.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSensorConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSensorConnected ? 'Wearable Sensor Connected' : 'Sensor Disconnected',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _isSensorConnected ? AppTheme.navy : AppTheme.amberDim,
                    ),
                  ),
                  Text(
                    _isSensorConnected
                        ? 'Inteli-Arm-V2 • $_sensorBattery% Battery • 8ms latency'
                        : 'Tap to pair wearable sensor before session',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isSensorConnected ? AppTheme.slate600 : AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _isSensorConnected ? AppTheme.primaryTeal : AppTheme.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareTeamCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.tealSoftBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: AppTheme.primaryTeal, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Ayub Medical Complex',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.slate800),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.greenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Verified Clinic',
                        style: TextStyle(fontSize: 14, color: AppTheme.green, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Physiotherapist: Dr. Tehreem (DRID001)',
                  style: TextStyle(fontSize: 14, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Diagnosis: ${_currentPatient.injury ?? "Shoulder & Elbow Rehab"}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayRehabHeroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, AppTheme.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 6),
                    Text(
                      "TODAY'S PRESCRIPTION",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tealBright.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Target: 90° ROM',
                  style: TextStyle(color: AppTheme.tealBright, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Elbow Flexion & Extension',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Controlled full-arc joint bend to strengthen bicep/tricep and prevent elbow adhesion.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPrescriptionChip(Icons.repeat_rounded, '3 Sets'),
              const SizedBox(width: 10),
              _buildPrescriptionChip(Icons.fitness_center_rounded, '10 Reps/Set'),
              const SizedBox(width: 10),
              _buildPrescriptionChip(Icons.speed_rounded, 'Moderate Pace'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PreSessionCheckScreen(
                    exerciseName: 'Elbow Flexion & Extension',
                    targetReps: 10,
                    targetSets: 3,
                    targetRom: _targetRom,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealBright,
              foregroundColor: AppTheme.navy,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 24),
                SizedBox(width: 8),
                Text(
                  'Start Rehab Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    final double romPercentage = (_currentRom / _targetRom).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recovery Biofeedback',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.slate800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // ROM Progress Ring Card
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: romPercentage,
                            strokeWidth: 8,
                            backgroundColor: AppTheme.tealLight,
                            color: AppTheme.primaryTeal,
                            strokeCap: StrokeCap.round,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_currentRom.toInt()}°',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: AppTheme.navy,
                                ),
                              ),
                              Text(
                                '/${_targetRom.toInt()}°',
                                style: const TextStyle(fontSize: 14, color: AppTheme.slate500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Max ROM Reached',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slate800),
                    ),
                    Text(
                      '${(romPercentage * 100).toInt()}% of Target',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Streak & Fatigue Column
            Expanded(
              child: Column(
                children: [
                  // Streak Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.amberLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_fire_department_rounded, color: AppTheme.amber, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_streakDays Days',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.slate800),
                            ),
                            const Text(
                              'Active Streak 🔥',
                              style: TextStyle(fontSize: 14, color: AppTheme.slate500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Fatigue Safety Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.greenLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt_rounded, color: AppTheme.green, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Low Strain',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppTheme.green),
                            ),
                            Text(
                              'Muscle Fatigue Safe',
                              style: TextStyle(fontSize: 14, color: AppTheme.slate500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Shortcuts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slate800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionCard(
              title: 'Pair Device',
              subtitle: 'BLE Wearable',
              icon: Icons.bluetooth_rounded,
              color: AppTheme.primaryTeal,
              onTap: () => _onTabTapped(2),
            ),
            const SizedBox(width: 10),
            _buildActionCard(
              title: 'Calibrate',
              subtitle: 'Baseline IMU',
              icon: Icons.tune_rounded,
              color: AppTheme.navyMid,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SensorCalibrationScreen()),
                );
              },
            ),
            const SizedBox(width: 10),
            _buildActionCard(
              title: 'Exercises',
              subtitle: '8 Plans',
              icon: Icons.library_books_rounded,
              color: AppTheme.tealBright,
              iconColor: AppTheme.navy,
              onTap: () => _onTabTapped(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slate800),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: AppTheme.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSessionsFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Sessions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slate800),
            ),
            TextButton(
              onPressed: () => _onTabTapped(3), // Progress tab
              child: const Text(
                'View All →',
                style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        _buildSessionFeedTile(
          date: 'Yesterday, 4:30 PM',
          exercise: 'Elbow Flexion & Extension',
          reps: '30 Reps Completed',
          maxRom: '88° Peak ROM',
          accuracy: '94% Form',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionReplayScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildSessionFeedTile(
          date: '24 Sep, 11:15 AM',
          exercise: 'Shoulder External Rotation',
          reps: '25 Reps Completed',
          maxRom: '68° Peak ROM',
          accuracy: '90% Form',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionReplayScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionFeedTile({
    required String date,
    required String exercise,
    required String reps,
    required String maxRom,
    required String accuracy,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded, color: AppTheme.primaryTeal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.slate800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$date • $reps',
                    style: const TextStyle(fontSize: 14, color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.greenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    accuracy,
                    style: const TextStyle(fontSize: 14, color: AppTheme.green, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  maxRom,
                  style: const TextStyle(fontSize: 14, color: AppTheme.slate600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
