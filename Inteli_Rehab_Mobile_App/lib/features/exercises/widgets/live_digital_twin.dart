import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../exercises_models.dart';

/// Application Layer's Digital Twin (SDD §3.1.3/3.1.4): the genuinely live
/// view (gap #1's corrected home for this) — repaints on every simulator
/// tick with the Intelligence & Processing Layer's own output (SensorFusion's
/// angle, AiEngine's safety tier), so the twin and the SafetyBanner beneath
/// it always agree — "AI results → Live 3D model + alerts" (SDD §3.1.9).
class LiveDigitalTwin extends StatelessWidget {
  final int angleDegrees;
  final SafetyTier tier;
  const LiveDigitalTwin({super.key, required this.angleDegrees, required this.tier});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (tier) {
      SafetyTier.normal => c.success,
      SafetyTier.needsCorrection => c.accent,
      SafetyTier.unsafe => c.alert,
    };
    final state = switch (tier) {
      SafetyTier.normal => 'good form',
      SafetyTier.needsCorrection => 'needs correction',
      SafetyTier.unsafe => 'potentially unsafe',
    };
    return Semantics(
      image: true,
      label: 'Live 3D model of your arm movement. At $angleDegrees percent, $state.',
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _TwinPainter(angleDegrees.toDouble(), color, c)),
      ),
    );
  }
}

class _TwinPainter extends CustomPainter {
  final double angle;
  final Color jointColor;
  final AppColors c;
  const _TwinPainter(this.angle, this.jointColor, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    double rad(num deg) => deg * math.pi / 180;

    final grid = Paint()
      ..color = c.muted.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var x = 10.0; x < 90; x += 6) {
      canvas.drawLine(Offset(x, 50), Offset(x + 3, 50), grid);
      canvas.drawLine(Offset(50, x), Offset(50, x + 3), grid);
    }

    final bone = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 18), const Offset(50, 50), bone..color = c.border);
    final end = Offset(50 - 28 * math.sin(rad(angle)), 50 + 28 * math.cos(rad(angle)));
    canvas.drawLine(const Offset(50, 50), end, bone..color = jointColor);

    canvas.drawCircle(const Offset(50, 50), 5.5, Paint()..color = jointColor);
    canvas.drawCircle(
      const Offset(50, 50),
      5.5,
      Paint()
        ..color = c.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(end, 4, Paint()..color = jointColor);
  }

  @override
  bool shouldRepaint(covariant _TwinPainter old) => old.angle != angle || old.jointColor != jointColor || old.c != c;
}
