import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Port of the portal's RadialProgress.jsx: a ring filled clockwise from
/// 12 o'clock, with an optional centred label.
class RadialProgress extends StatelessWidget {
  /// 0.0 – 1.0
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? center;

  const RadialProgress({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.color,
    this.track,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, stroke, color ?? c.primary, track ?? c.border),
          child: Center(child: child),
        ),
        child: center,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value, stroke;
  final Color color, track;
  const _RingPainter(this.value, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(ring, 0, math.pi * 2, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(
        ring,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        base
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke;
}
