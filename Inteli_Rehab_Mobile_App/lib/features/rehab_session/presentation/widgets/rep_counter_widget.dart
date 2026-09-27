import 'package:flutter/material.dart';

class RepCounterWidget extends StatelessWidget {
  final int completedReps;
  final int targetReps;

  const RepCounterWidget({
    super.key,
    this.completedReps = 0,
    this.targetReps = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Reps: $completedReps / $targetReps'),
    );
  }
}
