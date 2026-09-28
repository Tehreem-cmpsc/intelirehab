import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Circular arc indicator showing current ROM vs target ROM.
/// Color changes: green (≥80%), orange (50-79%), red (<50%)
class RomProgressRing extends StatelessWidget {
  final double currentRom;
  final double targetRom;
  final double size;
  final double strokeWidth;
  final String? label;

  const RomProgressRing({
    super.key,
    required this.currentRom,
    required this.targetRom,
    this.size = 120,
    this.strokeWidth = 12,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (targetRom == 0)
        ? 0.0
        : (currentRom / targetRom).clamp(0.0, 1.0);
    final color = progress >= 0.8
        ? Colors.green
        : progress >= 0.5
        ? Colors.orange
        : Colors.red;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${currentRom.toStringAsFixed(0)}°',
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(fontSize: size * 0.12, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = Colors.grey.shade200
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
