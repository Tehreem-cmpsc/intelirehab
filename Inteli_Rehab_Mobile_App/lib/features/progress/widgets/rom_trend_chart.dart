import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../progress_models.dart';

/// Two labeled lines, not two unlabeled colors (Rule 9): "Your ROM"
/// (solid) vs. "Target ROM" (dashed), with a visible legend — style
/// (solid/dashed) carries the meaning as much as color, so the chart
/// still reads if the two hues are hard to tell apart.
class RomTrendChart extends StatelessWidget {
  final List<RomTrendPoint> points;
  const RomTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasTarget = points.any((p) => p.target != null);
    final latest = points.isEmpty ? null : points.last;
    final spoken = latest == null
        ? 'ROM trend chart. No sessions yet.'
        : 'ROM trend chart over ${points.length} session${points.length == 1 ? '' : 's'}. '
            'Latest ${latest.achieved} percent${latest.target == null ? '' : ', target ${latest.target} percent'}. '
            'First ${points.first.achieved} percent.';

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendEntry(color: c.primary, dashed: false, label: 'Your ROM'),
              const SizedBox(width: 16),
              if (hasTarget) _LegendEntry(color: c.muted, dashed: true, label: 'Target ROM'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ChartPainter(points: points, colors: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final bool dashed;
  final String label;
  const _LegendEntry({required this.color, required this.dashed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 18, height: 10, child: CustomPaint(painter: _LinePreviewPainter(color: color, dashed: dashed))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.muted)),
      ],
    );
  }
}

class _LinePreviewPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _LinePreviewPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, size.width), y), paint);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePreviewPainter old) => old.color != color || old.dashed != dashed;
}

class _ChartPainter extends CustomPainter {
  final List<RomTrendPoint> points;
  final AppColors colors;
  const _ChartPainter({required this.points, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 8.0, bottomPad = 20.0, sidePad = 4.0;
    final plotHeight = size.height - topPad - bottomPad;
    final plotWidth = size.width - sidePad * 2;

    final gridPaint = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = topPad + plotHeight * (1 - frac);
      canvas.drawLine(Offset(sidePad, y), Offset(size.width - sidePad, y), gridPaint);
    }

    if (points.isEmpty) return;

    double xAt(int i) => points.length == 1 ? sidePad : sidePad + plotWidth * (i / (points.length - 1));
    double yAt(int value) => topPad + plotHeight * (1 - (value.clamp(0, 100) / 100));

    void drawLine(List<Offset?> pts, Color color, {bool dashed = false}) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        if (a == null || b == null) continue;
        if (!dashed) {
          canvas.drawLine(a, b, paint);
        } else {
          final dist = (b - a).distance;
          final steps = (dist / 8).ceil().clamp(1, 999);
          for (var s = 0; s < steps; s += 2) {
            final t0 = s / steps, t1 = ((s + 1).clamp(0, steps)) / steps;
            canvas.drawLine(Offset.lerp(a, b, t0)!, Offset.lerp(a, b, t1)!, paint);
          }
        }
      }
      for (final p in pts) {
        if (p != null) canvas.drawCircle(p, 3, Paint()..color = color);
      }
    }

    final achievedPts = [for (var i = 0; i < points.length; i++) Offset(xAt(i), yAt(points[i].achieved))];
    final targetPts = [
      for (var i = 0; i < points.length; i++) points[i].target == null ? null : Offset(xAt(i), yAt(points[i].target!)),
    ];

    drawLine(targetPts, colors.muted, dashed: true);
    drawLine(achievedPts, colors.primary);

    // A couple of date labels so the x-axis reads as "sessions over time".
    void label(String text, double x, {required bool right}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: colors.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(right ? x - tp.width : x, size.height - tp.height));
    }

    label(_shortDate(points.first.date), sidePad, right: false);
    if (points.length > 1) label(_shortDate(points.last.date), size.width - sidePad, right: true);
  }

  static String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.points != points || old.colors != colors;
}
