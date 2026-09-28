import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Stylised side view of an arm (shoulder -> hand) with tappable regions
/// for upper_arm / elbow / forearm. Mirrored for the left arm so the
/// shoulder always sits on the body side.
class ArmDiagram extends StatelessWidget {
  final String? side; // 'left' | 'right'
  final String? selected; // 'upper_arm' | 'elbow' | 'forearm'
  final ValueChanged<String> onSelected;

  const ArmDiagram({super.key, required this.side, required this.selected, required this.onSelected});

  static const _elbowStart = 0.40;
  static const _elbowEnd = 0.56;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mirrored = side == 'left';
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        onTapUp: (d) {
          var x = d.localPosition.dx / width;
          if (mirrored) x = 1 - x;
          if (x < _elbowStart) {
            onSelected('upper_arm');
          } else if (x <= _elbowEnd) {
            onSelected('elbow');
          } else {
            onSelected('forearm');
          }
        },
        child: Container(
          height: 116,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: CustomPaint(
            size: Size(width, 116),
            painter: _ArmPainter(selected: selected, colors: c, mirrored: mirrored),
          ),
        ),
      );
    });
  }
}

class _ArmPainter extends CustomPainter {
  final String? selected;
  final AppColors colors;
  final bool mirrored;
  _ArmPainter({required this.selected, required this.colors, required this.mirrored});

  /// Horizontal fraction -> x, flipped for the left arm. Text stays upright
  /// because only coordinates are mirrored, not the canvas.
  double _x(Size size, double f) => size.width * (mirrored ? 1 - f : f);

  Rect _span(Size size, double from, double to, double top, double bottom) =>
      Rect.fromPoints(Offset(_x(size, from), top), Offset(_x(size, to), bottom));

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;

    Paint fill(String region) => Paint()
      ..color = region == selected ? colors.primary : colors.primaryTint
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = colors.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Torso edge, so it reads as "shoulder on this side".
    final torso = RRect.fromRectAndRadius(_span(size, -0.1, 0.08, 8, size.height - 8), const Radius.circular(14));
    canvas.drawRRect(torso, Paint()..color = colors.border);

    final upper = RRect.fromRectAndRadius(
      _span(size, 0.07, 0.45, cy - 17, cy + 17),
      const Radius.circular(17),
    );
    final fore = RRect.fromRectAndRadius(
      _span(size, 0.51, 0.84, cy - 13, cy + 13),
      const Radius.circular(13),
    );
    canvas.drawRRect(upper, fill('upper_arm'));
    canvas.drawRRect(upper, outline);
    canvas.drawRRect(fore, fill('forearm'));
    canvas.drawRRect(fore, outline);

    // Hand
    final hand = RRect.fromRectAndRadius(
      _span(size, 0.85, 0.94, cy - 15, cy + 15),
      const Radius.circular(12),
    );
    canvas.drawRRect(hand, Paint()..color = colors.border);

    // Elbow joint on top, so it overlaps both segments.
    final elbowCenter = Offset(_x(size, 0.48), cy);
    canvas.drawCircle(elbowCenter, 20, fill('elbow'));
    canvas.drawCircle(elbowCenter, 20, outline);

    _label(canvas, 'Upper arm', Offset(_x(size, 0.26), cy + 30), selected == 'upper_arm');
    _label(canvas, 'Elbow', Offset(_x(size, 0.48), cy - 38), selected == 'elbow');
    _label(canvas, 'Forearm', Offset(_x(size, 0.675), cy + 30), selected == 'forearm');
  }

  void _label(Canvas canvas, String text, Offset center, bool active) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? colors.primary : colors.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ArmPainter old) =>
      old.selected != selected || old.colors != colors || old.mirrored != mirrored;
}
