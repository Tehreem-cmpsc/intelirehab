import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../session_replay/presentation/screens/session_replay_screen.dart';

class ProgressScreen extends StatefulWidget {
  final bool isEmbedded;

  const ProgressScreen({super.key, this.isEmbedded = false});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'Mon', 'rom': 55.0, 'completed': true},
    {'day': 'Tue', 'rom': 62.0, 'completed': true},
    {'day': 'Wed', 'rom': 68.0, 'completed': true},
    {'day': 'Thu', 'rom': 74.0, 'completed': true},
    {'day': 'Fri', 'rom': 88.0, 'completed': true},
    {'day': 'Sat', 'rom': 0.0, 'completed': false},
    {'day': 'Sun', 'rom': 0.0, 'completed': false},
  ];

  final List<Map<String, dynamic>> _milestones = [
    {
      'title': 'Post-Surgical Immobilization Exit',
      'date': 'Week 1 Completed',
      'status': 'Achieved',
      'icon': Icons.task_alt_rounded,
      'isDone': true,
    },
    {
      'title': '60° Passive Range of Motion',
      'date': 'Week 2 Completed',
      'status': 'Achieved',
      'icon': Icons.task_alt_rounded,
      'isDone': true,
    },
    {
      'title': '80° Active Flexion Milestone',
      'date': 'Week 3 Completed',
      'status': 'Achieved',
      'icon': Icons.task_alt_rounded,
      'isDone': true,
    },
    {
      'title': '90° Functional Clinical Goal',
      'date': 'Week 4 Target (Current)',
      'status': 'In Progress (88% done)',
      'icon': Icons.hourglass_bottom_rounded,
      'isDone': false,
    },
    {
      'title': 'Elastic Band Resistance Phase',
      'date': 'Prescribed by Dr. Tehreem',
      'status': 'Upcoming',
      'icon': Icons.lock_clock_rounded,
      'isDone': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Recovery Progress'),
        automaticallyImplyLeading: !widget.isEmbedded,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Overall Recovery Score Hero Card ───────────────────────────────
            _buildRecoveryHeroCard(),
            const SizedBox(height: 20),

            // ── Weekly ROM Trajectory Chart ────────────────────────────────────
            _buildWeeklyTrajectoryCard(),
            const SizedBox(height: 20),

            // ── 7-Day Adherence Calendar ───────────────────────────────────────
            _buildAdherenceCalendar(),
            const SizedBox(height: 20),

            // ── Clinical Milestones ────────────────────────────────────────────
            _buildMilestonesSection(),
            const SizedBox(height: 20),

            // ── Historical Sessions Feed ───────────────────────────────────────
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tealBright.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'CLINICAL TRAJECTORY',
                    style: TextStyle(color: AppTheme.tealBright, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '78% Recovered',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Current status: On Track (+12% above projected recovery speed).',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up_rounded, color: AppTheme.tealBright, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrajectoryCard() {
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
              const Text(
                'Weekly Joint ROM Arc',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Goal: 90°',
                  style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Bar Chart Simulation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _weeklyData.map((d) {
              final double rom = d['rom'] as double;
              final bool isDone = d['completed'] as bool;
              final double barHeight = (rom / 100.0 * 120.0).clamp(8.0, 120.0);

              return Column(
                children: [
                  if (isDone)
                    Text(
                      '${rom.toInt()}°',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: isDone ? barHeight : 10,
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.primaryTeal : AppTheme.slate200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d['day'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDone ? AppTheme.slate800 : AppTheme.slate500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCalendar() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Session Adherence',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
              ),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppTheme.amber, size: 18),
                  SizedBox(width: 4),
                  Text(
                    '5 Day Streak',
                    style: TextStyle(color: AppTheme.amber, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((entry) {
              final idx = entry.key;
              final letter = entry.value;
              final isCompleted = idx < 5;

              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppTheme.greenLight : AppTheme.slate100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? AppTheme.green : AppTheme.slate200,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, color: AppTheme.green, size: 18)
                          : Text(
                              letter,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate500),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Day ${idx + 1}',
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.slate500),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesSection() {
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
            'Clinical Recovery Milestones',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _milestones.length,
            separatorBuilder: (_, __) => const Divider(height: 18, color: AppTheme.slate100),
            itemBuilder: (context, idx) {
              final m = _milestones[idx];
              final isDone = m['isDone'] as bool;

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.greenLight : AppTheme.slate100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      m['icon'] as IconData,
                      color: isDone ? AppTheme.green : AppTheme.slate500,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['title'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDone ? AppTheme.slate800 : AppTheme.slate600,
                          ),
                        ),
                        Text(
                          m['date'] as String,
                          style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDone ? AppTheme.greenLight : AppTheme.tealLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m['status'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppTheme.green : AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Past Sessions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate800),
        ),
        const SizedBox(height: 10),
        _buildHistoryCard(
          exercise: 'Elbow Flexion & Extension',
          date: 'Yesterday • 4:30 PM',
          reps: '30 Reps (3 Sets)',
          peakRom: '88° Peak',
          score: '94% Form Score',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionReplayScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildHistoryCard(
          exercise: 'Shoulder External Rotation',
          date: '24 Sep • 11:15 AM',
          reps: '25 Reps (3 Sets)',
          peakRom: '68° Peak',
          score: '90% Form Score',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionReplayScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryCard({
    required String exercise,
    required String date,
    required String reps,
    required String peakRom,
    required String score,
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
              child: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.primaryTeal, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.slate800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$date • $reps',
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  peakRom,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryTeal),
                ),
                Text(
                  score,
                  style: const TextStyle(fontSize: 10.5, color: AppTheme.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
