import 'package:flutter/material.dart';

/// Reusable streak badge showing consecutive session days.
class StreakBadge extends StatelessWidget {
  final int streakDays;
  final double size;

  const StreakBadge({
    super.key,
    required this.streakDays,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_fire_department, color: Colors.white, size: size * 0.35),
          Text(
            '$streakDays',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.22,
              height: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}
