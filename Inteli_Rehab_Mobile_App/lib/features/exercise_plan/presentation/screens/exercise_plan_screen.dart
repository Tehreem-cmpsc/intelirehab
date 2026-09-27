import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../rehab_session/presentation/screens/pre_session_check_screen.dart';

class ExercisePlanScreen extends StatefulWidget {
  final bool isEmbedded;

  const ExercisePlanScreen({super.key, this.isEmbedded = false});

  @override
  State<ExercisePlanScreen> createState() => _ExercisePlanScreenState();
}

class _ExercisePlanScreenState extends State<ExercisePlanScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';

  // 8 Clinic-Approved Exercises from https://inteli-rehab.vercel.app/
  final List<Map<String, dynamic>> _exercises = [
    {
      'id': 1,
      'name': 'Elbow Flexion & Extension',
      'target': 'Bicep / Tricep',
      'difficulty': 'Beginner',
      'sets': 3,
      'reps': 10,
      'romTarget': 90.0,
      'isAssignedToday': true,
      'image': 'assets/images/elbow_flexion.png',
      'desc': 'Controlled full-arc elbow bend to rebuild bicep/tricep strength and joint mobility.',
      'instructions': [
        'Stand or sit tall with your back straight.',
        'Keep your elbow close to your torso.',
        'Bend elbow upwards smoothly until 90° ROM is reached.',
        'Slowly extend back to resting baseline.',
      ],
    },
    {
      'id': 2,
      'name': 'Shoulder External Rotation',
      'target': 'Rotator Cuff',
      'difficulty': 'Intermediate',
      'sets': 3,
      'reps': 12,
      'romTarget': 70.0,
      'isAssignedToday': false,
      'image': 'assets/images/shoulder_flexion.png',
      'desc': 'Outward arm rotation against gravity to restore rotator cuff stabilization.',
      'instructions': [
        'Keep upper arm pressed gently to your side at 90° bend.',
        'Rotate forearm outward away from your abdomen.',
        'Hold for 1 second at 70° before returning.',
      ],
    },
    {
      'id': 3,
      'name': 'Forearm Supination & Pronation',
      'target': 'Forearm muscles',
      'difficulty': 'Beginner',
      'sets': 3,
      'reps': 15,
      'romTarget': 80.0,
      'isAssignedToday': false,
      'image': 'assets/images/forearm_pronation.jpg',
      'desc': 'Twisting forearm palm-up and palm-down to restore axial pronation range.',
      'instructions': [
        'Rest forearm on armrest or thigh.',
        'Turn palm completely upward (supination).',
        'Rotate 180° until palm faces downward (pronation).',
      ],
    },
    {
      'id': 4,
      'name': 'Shoulder Abduction Raise',
      'target': 'Deltoid / Supraspinatus',
      'difficulty': 'Intermediate',
      'sets': 3,
      'reps': 10,
      'romTarget': 90.0,
      'isAssignedToday': true,
      'image': 'assets/images/shoulder_abduction.jpg',
      'desc': 'Lateral arm raise to 90° targeting deltoid and supraspinatus rehabilitation.',
      'instructions': [
        'Raise arm out to the side with thumb slightly up.',
        'Lift until parallel with the floor (90°).',
        'Lower smoothly with controlled cadence.',
      ],
    },
    {
      'id': 5,
      'name': 'Wrist Flexion Curl',
      'target': 'Wrist flexors',
      'difficulty': 'Beginner',
      'sets': 3,
      'reps': 12,
      'romTarget': 60.0,
      'isAssignedToday': false,
      'image': 'assets/images/elbow_extension.jpg',
      'desc': 'Gentle wrist curl to rebuild grip and forearm flexor strength post-cast.',
      'instructions': [
        'Support forearm flat on table with hand over the edge.',
        'Curl wrist upwards gently, holding for 1 second.',
        'Lower to comfortable baseline extension.',
      ],
    },
    {
      'id': 6,
      'name': 'Scapular Retraction',
      'target': 'Rhomboids / Traps',
      'difficulty': 'Advanced',
      'sets': 3,
      'reps': 10,
      'romTarget': 45.0,
      'isAssignedToday': false,
      'image': 'assets/images/header_pic.jpeg',
      'desc': 'Squeeze shoulder blades together for thoracic posture correction and scapular rhythm.',
      'instructions': [
        'Relax shoulders down and away from ears.',
        'Pinch shoulder blades backwards toward spine.',
        'Hold for 3 seconds then release.',
      ],
    },
    {
      'id': 7,
      'name': 'Pendulum Arm Swing',
      'target': 'Shoulder capsule',
      'difficulty': 'Beginner',
      'sets': 2,
      'reps': 20,
      'romTarget': 30.0,
      'isAssignedToday': false,
      'image': 'assets/images/rehab_welcome_illustration.jpg',
      'desc': 'Passive gravitational swing to gently decompress the glenohumeral joint.',
      'instructions': [
        'Lean forward placing non-injured hand on a table.',
        'Let injured arm dangle freely like a pendulum.',
        'Gently sway body in circular arcs.',
      ],
    },
    {
      'id': 8,
      'name': 'Isometric Bicep Hold',
      'target': 'Bicep (isometric)',
      'difficulty': 'Beginner',
      'sets': 3,
      'reps': 10,
      'romTarget': 45.0,
      'isAssignedToday': false,
      'image': 'assets/images/daily_tip.jpeg',
      'desc': 'Static contraction hold to activate muscle fibers without joint stress.',
      'instructions': [
        'Bend elbow to 90° angle.',
        'Press forearm against opposite hand with moderate resistance.',
        'Hold isometric contraction for 5 seconds per rep.',
      ],
    },
  ];

  List<Map<String, dynamic>> get _filteredExercises {
    return _exercises.where((ex) {
      final matchesSearch = ex['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ex['target'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Assigned Today') return ex['isAssignedToday'] == true;
      if (_selectedFilter == 'Beginner') return ex['difficulty'] == 'Beginner';
      if (_selectedFilter == 'Intermediate') return ex['difficulty'] == 'Intermediate';
      if (_selectedFilter == 'Advanced') return ex['difficulty'] == 'Advanced';
      return true;
    }).toList();
  }

  void _showExerciseModal(Map<String, dynamic> ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ex['difficulty'],
                    style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.greenLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Target: ${ex['romTarget']}° ROM',
                    style: const TextStyle(color: AppTheme.green, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ex['name'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.slate800),
            ),
            const SizedBox(height: 4),
            Text(
              'Target Muscle: ${ex['target']}',
              style: const TextStyle(fontSize: 13, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Text(
              ex['desc'],
              style: const TextStyle(fontSize: 13.5, color: AppTheme.slate600, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Step-by-Step Instructions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.slate800),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: (ex['instructions'] as List<String>).length,
                itemBuilder: (context, idx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppTheme.tealSoftBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTealDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ex['instructions'][idx],
                            style: const TextStyle(fontSize: 13, color: AppTheme.slate800, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PreSessionCheckScreen(
                      exerciseName: ex['name'] as String,
                      targetReps: ex['reps'] as int,
                      targetSets: ex['sets'] as int,
                      targetRom: ex['romTarget'] as double,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Start This Exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Rehabilitation Plans'),
        automaticallyImplyLeading: !widget.isEmbedded,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search prescribed exercises…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Assigned Today', 'Beginner', 'Intermediate', 'Advanced'].map((chip) {
                  final isSelected = _selectedFilter == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedFilter = chip),
                      selectedColor: AppTheme.tealLight,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryTealDark : AppTheme.slate600,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(color: isSelected ? AppTheme.primaryTeal : AppTheme.slate200),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Exercises Count Header
            Text(
              '${_filteredExercises.length} Clinic-Prescribed Exercises',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.slate800),
            ),
            const SizedBox(height: 12),

            // Exercises Grid
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredExercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ex = _filteredExercises[index];
                return _buildExerciseCard(ex);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> ex) {
    final isAssigned = ex['isAssignedToday'] == true;

    return InkWell(
      onTap: () => _showExerciseModal(ex),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAssigned ? AppTheme.primaryTeal.withValues(alpha: 0.35) : AppTheme.slate200,
            width: isAssigned ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isAssigned ? AppTheme.primaryTeal.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ex['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.slate800),
                  ),
                ),
                if (isAssigned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.tealLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Today\'s Plan',
                      style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold, fontSize: 10.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Target: ${ex['target']}',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              ex['desc'] as String,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.slate500, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCardPill('${ex['sets']} Sets × ${ex['reps']} Reps'),
                const SizedBox(width: 8),
                _buildCardPill('Target: ${ex['romTarget']}° ROM'),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryTeal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate600),
      ),
    );
  }
}
