import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/dashed_ring.dart';
import '../../core/widgets/theme_toggle.dart';
import '../auth/login_screen.dart';
import 'onboarding_flow.dart';

// Fixed hero colours from the portal's LandingPage.jsx — like the portal,
// the hero stays dark in both themes; the bottom panel follows the
// light/dark tokens.
const _heroBg = Color(0xFF093D42);
const _cardBg = Color(0xFF112F35);
const _cardBorder = Color(0xFF1E4A52);
const _well = Color(0xFF071F24);
const _mint = Color(0xFF31E8C6);
const _amber = Color(0xFFE7A24C);
const _greenSoft = Color(0xFF6CE09F);

/// Signed-out landing screen. A single, non-scrolling screen in the usual
/// mobile-app shape — brand + visual on top, headline and actions in a
/// bottom panel — styled after the web portal's LandingPage hero.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _heroBg,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned(
                  right: -130,
                  top: -110,
                  child:
                      DashedRing(size: 380, dash: 14, gap: 18, strokeWidth: 2.5, color: Color(0x1FFFFFFF), spin: true),
                ),
                Positioned(
                  left: -70,
                  bottom: -40,
                  child: IgnorePointer(child: CustomPaint(size: const Size.square(240), painter: _CrosshairPainter())),
                ),
                const SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: AppLogo(size: 34, onDark: true),
                              ),
                            ),
                            SizedBox(width: 12),
                            ThemeToggle(onDark: true),
                          ],
                        ),
                      ),
                      // The visual absorbs whatever height is left, scaling
                      // down on short screens so nothing ever needs to scroll.
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(28, 16, 28, 24),
                          child: Center(
                            child: FittedBox(fit: BoxFit.scaleDown, child: _LiveMonitorCard()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _BottomPanel(),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: c.accent),
                    const SizedBox(width: 6),
                    Text(
                      'INTELI-REHAB PATIENT APP',
                      style:
                          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: c.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Recover at home.\nTrack your progress objectively.',
            style:
                TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5, color: c.ink),
          ),
          const SizedBox(height: 10),
          Text(
            'Your physiotherapist sets the plan. Your Inteli Band measures every rep, so they can see '
            'exactly how you are recovering.',
            style: TextStyle(fontSize: 14.5, height: 1.45, color: c.muted),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingFlow())),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text('Get started'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }
}

/// Compact take on the portal's "Live Wearable Monitor" card. Instead of
/// a slider (a fixed screen has no room for one), the joint sweeps by
/// itself through its range; with reduced motion it rests inside the
/// target zone.
class _LiveMonitorCard extends StatefulWidget {
  const _LiveMonitorCard();

  @override
  State<_LiveMonitorCard> createState() => _LiveMonitorCardState();
}

class _LiveMonitorCardState extends State<_LiveMonitorCard> with SingleTickerProviderStateMixin {
  static const _targetMin = 85;
  static const _targetMax = 115;

  /// ≈96°, inside the target zone — where the joint rests with reduced motion.
  static const _restingValue = 0.6;
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200), value: _restingValue);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep
        ..stop()
        ..value = _restingValue;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
      color: Colors.white.withValues(alpha: 0.5),
    );
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final angle = 20 + 115 * Curves.easeInOut.transform(_sweep.value);
        final inTarget = angle >= _targetMin && angle <= _targetMax;
        return Container(
          width: 300,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'LIVE WEARABLE MONITOR',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: _mint),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C9F70).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        _PingDot(),
                        SizedBox(width: 5),
                        Text('Synced', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _greenSoft)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _well,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0D2D34)),
                ),
                child: Stack(
                  children: [
                    Positioned(left: 12, top: 10, child: Text('JOINT SCHEMA', style: labelStyle)),
                    Center(
                      child: CustomPaint(
                        size: const Size.square(170),
                        painter: _JointPainter(angle, _targetMin, _targetMax, inTarget),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ELBOW FLEXION', style: labelStyle),
                      const SizedBox(height: 2),
                      Text(
                        '${angle.round()}°',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _mint,
                          height: 1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (inTarget ? const Color(0xFF4C9F70) : _amber).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                inTarget ? Icons.check_circle_outline : Icons.monitor_heart_outlined,
                                size: 14,
                                color: inTarget ? _greenSoft : _amber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                inTarget ? 'Target achieved' : 'Range check',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: inTarget ? _greenSoft : _amber),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width * 0.4, paint);
    canvas.drawLine(Offset(size.width * 0.1, c.dy), Offset(size.width * 0.9, c.dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Same geometry as the portal's joint SVG (100x100 viewBox): upper arm
/// fixed vertically, forearm rotating from straight down, target arc at r=18.
class _JointPainter extends CustomPainter {
  final double angle;
  final int targetMin, targetMax;
  final bool inTarget;
  const _JointPainter(this.angle, this.targetMin, this.targetMax, this.inTarget);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    double rad(num deg) => deg * math.pi / 180;

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = 10.0; x < 90; x += 6) {
      canvas.drawLine(Offset(x, 50), Offset(x + 3, 50), grid);
      canvas.drawLine(Offset(50, x), Offset(50, x + 3), grid);
    }

    // Straight down is 90° in canvas terms; bending sweeps towards the left.
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(50, 50), radius: 18),
      math.pi / 2 + rad(targetMin),
      rad(targetMax - targetMin),
      false,
      Paint()
        ..color = const Color(0xFF4C9F70).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'TARGET ZONE ($targetMin°-$targetMax°)',
        style: TextStyle(
            fontSize: 6.5, fontWeight: FontWeight.w700, color: const Color(0xFF4C9F70).withValues(alpha: 0.9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(12, 86));

    final bone = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 18), const Offset(50, 50), bone..color = const Color(0xFFE4F1F0));
    final end = Offset(50 - 28 * math.sin(rad(angle)), 50 + 28 * math.cos(rad(angle)));
    canvas.drawLine(const Offset(50, 50), end, bone..color = inTarget ? _mint : _amber);

    canvas.drawCircle(const Offset(50, 50), 5, Paint()..color = _mint);
    canvas.drawCircle(
      const Offset(50, 50),
      5,
      Paint()
        ..color = _well
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _JointPainter old) => old.angle != angle;
}

class _PingDot extends StatefulWidget {
  const _PingDot();

  @override
  State<_PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<_PingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dot = SizedBox.square(
      dimension: 6,
      child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF4C9F70), shape: BoxShape.circle)),
    );
    return SizedBox.square(
      dimension: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.scale(
              scale: 1 + _c.value,
              child: Opacity(opacity: 1 - _c.value, child: child),
            ),
            child: dot,
          ),
          dot,
        ],
      ),
    );
  }
}
