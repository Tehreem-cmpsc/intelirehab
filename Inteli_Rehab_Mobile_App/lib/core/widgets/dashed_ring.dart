import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The portal's decorative dashed orbit (`strokeDasharray` circle), with
/// the optional slow `cp-arc-spin` rotation. Spinning is skipped when the
/// OS asks for reduced motion, as the portal's prefers-reduced-motion rule.
class DashedRing extends StatefulWidget {
  final double size;
  final double dash;
  final double gap;
  final double strokeWidth;
  final Color color;
  final bool spin;

  const DashedRing({
    super.key,
    required this.size,
    this.dash = 10,
    this.gap = 14,
    this.strokeWidth = 2,
    this.color = const Color(0x26FFFFFF),
    this.spin = false,
  });

  @override
  State<DashedRing> createState() => _DashedRingState();
}

class _DashedRingState extends State<DashedRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.spin && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = CustomPaint(
      size: Size.square(widget.size),
      painter: _DashedRingPainter(widget.dash, widget.gap, widget.strokeWidth, widget.color),
    );
    return IgnorePointer(
      child: widget.spin ? RotationTransition(turns: _controller, child: ring) : ring,
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final double dash, gap, strokeWidth;
  final Color color;
  const _DashedRingPainter(this.dash, this.gap, this.strokeWidth, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final r = size.width / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final count = (2 * math.pi * r / (dash + gap)).floor();
    final step = 2 * math.pi / count;
    final sweep = step * dash / (dash + gap);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * step, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) =>
      old.color != color || old.dash != dash || old.gap != gap || old.strokeWidth != strokeWidth;
}
