import 'package:flutter/material.dart';

class FatigueAlertWidget extends StatelessWidget {
  final bool isFatigueDetected;

  const FatigueAlertWidget({
    super.key,
    this.isFatigueDetected = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFatigueDetected) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text('Fatigue Detected', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
