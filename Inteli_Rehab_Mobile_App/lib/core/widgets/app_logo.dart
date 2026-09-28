import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Redraw of the web portal's mark (Intelli_Rehab_Web_Portal/src/
/// presentation/admin/components/Logo.jsx) — same 100x100 geometry and
/// the same two colour variants. Don't restyle it; see the portal file.
class _LogoPalette {
  final Color background, ring, accent, stroke, textPrimary, textSecondary;
  const _LogoPalette(this.background, this.ring, this.accent, this.stroke, this.textPrimary, this.textSecondary);
}

const _lightPalette = _LogoPalette(
  Color(0xFFE4FAF6),
  Color(0xFF00B9A0),
  Color(0xFF1CBDAF),
  Color(0xFF0F5D63),
  Color(0xFF12242B),
  Color(0xFF4C6360),
);

const _darkPalette = _LogoPalette(
  Color(0xFF0D2B38),
  Color(0xFF144F5A),
  Color(0xFF33E6D0),
  Color(0xFF81F6E8),
  Colors.white,
  Color(0xB8FFFFFF),
);

class AppLogoIcon extends StatelessWidget {
  final double size;

  /// `light` = the pale-circle variant, as the portal's `light` prop.
  final bool light;

  const AppLogoIcon({super.key, this.size = 40, this.light = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(light ? _lightPalette : _darkPalette),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool light;

  /// Forces white wordmark text, for use on the teal header gradient.
  final bool onDark;
  final bool showTagline;

  const AppLogo({
    super.key,
    this.size = 40,
    this.light = true,
    this.onDark = false,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = light ? _lightPalette : _darkPalette;
    // As the portal's LIGHT_COLORS (var(--ink) / var(--muted)): the
    // wordmark follows the current theme so it stays legible in dark mode.
    final tokens = Theme.of(context).extension<AppColors>();
    final primaryText = onDark ? Colors.white : (light ? tokens?.ink : null) ?? p.textPrimary;
    final secondaryText =
        onDark ? Colors.white.withValues(alpha: 0.72) : (light ? tokens?.muted : null) ?? p.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogoIcon(size: size, light: light),
        SizedBox(width: size * 0.3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Inteli', style: TextStyle(color: primaryText)),
                TextSpan(text: 'Rehab', style: TextStyle(color: p.accent)),
              ]),
              style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w900, letterSpacing: -0.4, height: 1.1),
            ),
            if (showTagline)
              Text(
                'SMART REHABILITATION',
                style: TextStyle(
                  fontSize: (size * 0.22).clamp(8, 12).toDouble(),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: secondaryText,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  final _LogoPalette p;
  const _LogoPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);

    canvas.drawCircle(const Offset(50, 50), 44, Paint()..color = p.background);
    canvas.drawCircle(
      const Offset(50, 50),
      34,
      Paint()
        ..color = p.ring.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final pulse = Path()
      ..moveTo(18, 60)
      ..lineTo(28, 60)
      ..lineTo(33, 46)
      ..lineTo(39, 74)
      ..lineTo(47, 46)
      ..lineTo(52, 66)
      ..lineTo(58, 55)
      ..lineTo(67, 55)
      ..cubicTo(72, 55, 78, 52, 82, 47);
    canvas.drawPath(
      pulse,
      Paint()
        ..color = p.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final arc = Path()
      ..moveTo(20, 52)
      ..cubicTo(28, 42, 42, 36, 54, 44)
      ..cubicTo(62, 50, 72, 60, 76, 68);
    canvas.drawPath(
      arc,
      Paint()
        ..color = p.stroke.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.p != p;
}
